require 'net/http'
require 'uri'

module CppSamples
	DEFAULT_SAMPLES_DIR = 'samples'
	COMMENT_REGEX = /^\/\/\s*(.+)?$/

	class SamplesGenerator < Jekyll::Generator
		def generate(site)
			index = site.pages.detect { |page| page.name == 'index.html' }

			samples_dir = site.config['samples_dir'] || DEFAULT_SAMPLES_DIR
			samples_tree = CppSamples::build_samples_tree(site, samples_dir)

			index.data['sample_categories'] = samples_tree
			index.data['random_sample'] = CppSamples::get_random_sample(samples_tree)

			samples_tree.each do |category, sections|
				sections.each do |section, samples|
					samples.each do |sample|
						site.pages << SamplePage.new(site, sample)
					end
				end
			end
		end
	end

	GithubUser = Struct.new(:username, :avatar, :profile)

	class GithubUserCache
		def initialize
			@cache = {}
			@usernames_cache = {}

			@github_token = ENV['GH_TOKEN']
		end

		def get_user_by_email(email)
			if @cache.has_key?(email)
				return @cache[email]
			end

			while true
				search_uri = URI.parse("https://api.github.com/search/users?q=#{email}+in:email&per_page=1")

				if @github_token.nil? or @github_token.empty?
					search_response = Net::HTTP.get_response(search_uri)
				else
					search_request = Net::HTTP::Get.new(search_uri)
					search_request.basic_auth(ENV['GH_TOKEN'], 'x-oauth-basic')
					search_response = Net::HTTP.start(search_uri.hostname,
					                                  search_uri.port,
					                                  :use_ssl => true) do |http|
						http.request(search_request)
					end
				end

				search_result = JSON.parse(search_response.body)

				break if search_result.has_key?('items')

				rate_limit_reset_timestamp = search_response['X-RateLimit-Reset'].to_i
				while Time.now.to_i < rate_limit_reset_timestamp
					sleep(30)
				end
			end

			if search_result['items'].empty?
				user = GithubUser.new(nil, '/images/unknown_user.png', nil)
			else
				user_item = search_result['items'][0]
				user = GithubUser.new(user_item['login'], user_item['avatar_url'] + '&size=36', user_item['html_url'])
			end

			@cache[email] = user
			if !user.username.nil?
				@usernames_cache[user.username] = user
			end

			user
		end

		def get_user_by_username(username)
			if @usernames_cache.has_key?(username)
				return @usernames_cache[username]
			end

			while true
				user_uri = URI.parse("https://api.github.com/users/#{username}")

				if @github_token.nil? or @github_token.empty?
					user_response = Net::HTTP.get_response(user_uri)
				else
					user_request = Net::HTTP::Get.new(user_uri)
					user_request.basic_auth(ENV['GH_TOKEN'], 'x-oauth-basic')
					user_response = Net::HTTP.start(user_uri.hostname,
					                                user_uri.port,
					                                :use_ssl => true) do |http|
						http.request(user_request)
					end
				end

				user_result = JSON.parse(user_response.body)

				break if user_result.has_key?('login') or
				         user_result['message'] == "Not Found"

				rate_limit_reset_timestamp = search_response['X-RateLimit-Reset'].to_i
				while Time.now.to_i < rate_limit_reset_timestamp
					sleep(30)
				end
			end

			if user_result.has_key?('login')
				user = GithubUser.new(username, user_result['avatar_url'] + '&size=36', user_result['html_url'])
			else
				user = GithubUser.new(username, '/images/unknown_user.png', nil)
			end

			@usernames_cache[username] = user
			if user_result.has_key?('email')
				@cache[user_result['email']] = user
			end
		end
	end

	class DummyUserCache
		def get_user_by_email(email)
			GithubUser.new(nil, '/images/unknown_user.png', nil)
		end

		def get_user_by_username(username)
			GithubUser.new(nil, '/images/unknown_user.png', nil)
		end
	end

	class SamplePage < Jekyll::Page
		def initialize(site, sample)
			@site = site
			@base = site.source
			@dir = File.dirname(sample.path)
			@name = "#{File.basename(sample.path)}.html"

			process(@name)
			read_yaml(File.join(@base, '_includes', ''), 'sample.html')

			self.data['sample'] = sample
			self.data['title'] = sample.title
			self.data['description'] = sample.intent
		end
	end

	class Section
		attr_accessor :title, :path

		def initialize(title_file_name)
			@path = File.dirname(title_file_name)

			title_file = File.new(title_file_name, 'r')
			@title = title_file.readline.chomp
		end

		def to_liquid
			return {'title' => @title, 'path' => @path}
		end
	end

	class Sample
		attr_accessor :file_name, :path, :code_offset, :title, :intent

		def initialize(sample_file_name, user_cache, contributors_list)
			@user_cache = user_cache

			sample_file = File.new(sample_file_name, 'r')

			@file_name = get_file_name(sample_file_name)
			@path = file_name_to_path(sample_file_name)

			sample_contents = strip_blank_lines(sample_file.readlines)

			@title = extract_title(sample_contents)
			@tags = extract_tags(sample_contents)

			code_start = 1
			code_start = 2 unless @tags.empty?

			body_lines, body_start = extract_body(sample_contents)
			@intent, @description = extract_body_parts(body_lines)

			code_lines = strip_blank_lines(sample_contents[code_start..body_start-1])
			@code = code_lines.join
			@code_offset = sample_contents.index(code_lines[0])

			@contributors = get_contributors(sample_file_name, contributors_list)
			@modified_date = get_modified_date(sample_file_name)
		end

		def to_liquid
			{
				'title' => @title,
				'tags' => @tags,
				'code' => @code,
				'code_offset' => @code_offset,
				'description' => @description,
				'intent' => @intent,
				'contributors' => @contributors,
				'modified_date' => @modified_date,
				'path' => @path,
				'file_name' => @file_name
			}
		end

		private def get_file_name(full_file_name)
			file_name_parts = full_file_name.split('/')[-3..-1]
			file_name_parts.join('/')
		end

		private def file_name_to_path(file_name)
			file_name_parts = file_name.split('/')[-3..-1]
			file_name_parts[2] = File.basename(file_name_parts[2], '.*')
			file_name_parts[0].slice!(/^\d+\-/)
			file_name_parts.delete_at(1)
			file_name_parts.join('/')
		end

		private def extract_title(lines)
			header = lines[0]
			header_match = COMMENT_REGEX.match(header)

			unless header_match
				raise "invalid header line in sample"
			end

			header_match[1]
		end

		private def extract_tags(lines)
			tags_line = lines[1]
			tags_line_match = COMMENT_REGEX.match(tags_line)

			unless tags_line_match
				return []
			end

			tags_text = tags_line_match[1]
			tags = tags_text.split(/\s*,\s*/)
			tags.collect! {|tag| tag.strip.downcase}

			return tags
		end

		private def extract_body(lines)
			body = []
			line_index = lines.length - 1

			while not COMMENT_REGEX.match(lines[line_index])
				line_index -= 1
			end

			while match = COMMENT_REGEX.match(lines[line_index])
				body.unshift("#{match[1]}\n")
				line_index -= 1
			end

			return body, line_index
		end

		private def extract_body_parts(body_lines)
			blank_line_index = body_lines.index {|line| /^[\t ]*\n$/ =~ line}
			intent = body_lines[0..blank_line_index].join()
			description = body_lines[blank_line_index+1..-1].join()
			return intent, description
		end

		private def strip_blank_lines(lines)
			lines.join("").strip.split("\n").map {|line| "#{line}\n" }
		end

		private def get_contributors(file_name, contributors_list)
			real_path = file_name.split('/')[-3..-1].join('/')

			committers = nil
			Dir.chdir('samples') do
				gitlog_output = `git log --follow --simplify-merges --format="format:%ae %an" -- #{real_path}`
				committer_strings = gitlog_output.split("\n")
				committers = committer_strings.inject([]) do |committers, committer_string|
					split_committer_string = committer_string.split(/\s/,2)
					committers << {'email' => split_committer_string[0], 'name' => split_committer_string[1]}
				end
			end

			committers.uniq! {|committer| committer['email'] }

			contributors = []

			committers.each do |committer|
				contributors_item = contributors_list.detect do |contributors_item|
					contributors_item['name'] == committer['name'] or
					contributors_item['email'] == committer['email']
				end

				unless contributors_item.nil?
					user = @user_cache.get_user_by_username(contributors_item['github_username'])
				end

				if user.nil? or user.username.nil?
					user = @user_cache.get_user_by_email(committer['email'])
				end

				contributors << {
					'name' => committer['name'],
					'image' => user.avatar,
					'url' => user.profile
				}
			end

			contributors
		end

		private def get_modified_date(file_name)
			real_path = file_name.split('/')[-3..-1].join('/')
			Dir.chdir('samples') do
				`git log -1 --format="format:%ad" -- #{real_path}`.strip
			end
		end
	end

	def self.build_samples_tree(site, samples_dir)
		sections = build_dir(samples_dir)

		if site.config['environment'] == "production"
			user_cache = GithubUserCache.new
		else
			user_cache = DummyUserCache.new
		end

		contributors_list = []
		File.open('samples/CONTRIBUTORS.txt', 'r').each_line do |line|
			match = /^\- ([^<>]*) (<(.*)> )?\((.*)\)\s*$/.match(line)
			contributors_list << {
				'name' => match[1],
				'email' => match[3],
				'github_username' => match[4]
			}
		end

		sections.inject({}) do |tree, section|
			categories = build_dir(section.path)

			tree[section] = categories.inject({}) do |tree_section, category|
				tree_section[category] = collect_samples(category.path, user_cache, contributors_list)
				tree_section
			end

			tree
		end
	end

	def self.build_dir(dir)
		subdir_title_file_names = Dir.glob("#{dir}/*/TITLE").sort

		subdir_title_file_names.inject([]) do |sections, subdir_title_file_name|
			sections << Section.new(subdir_title_file_name)
		end
	end

	def self.collect_samples(dir, user_cache, contributors_list)
		sample_file_names = Dir.glob("#{dir}/*.cpp").sort
		sample_file_names.inject([]) do |samples, sample_file_name|
			samples << Sample.new(sample_file_name, user_cache, contributors_list)
		end
	end

	def self.get_random_sample(samples_tree)
		all_samples = []

		samples_tree.each do |_, sections|
			sections.each do |_, samples|
				all_samples.concat(samples)
			end
		end

		seed = Time.now.strftime("%U%Y").to_i
		all_samples.sample(random: Random.new(seed))
	end
end
