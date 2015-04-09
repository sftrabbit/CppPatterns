require 'net/http'
require 'uri'

module CppSamples
	DEFAULT_SAMPLES_DIR = '_samples'
	COMMENT_REGEX = /^\/\/\s*(.+)?$/

	class SamplesGenerator < Jekyll::Generator
		def generate(site)
			index = site.pages.detect { |page| page.url == '/index.html' }

			samples_dir = site.config['samples_dir'] || DEFAULT_SAMPLES_DIR
			samples_tree = CppSamples::build_samples_tree(samples_dir)

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

	GithubUser = Struct.new(:avatar, :profile)

	class GithubUserCache
		def initialize
			@cache = {}
		end

		def get_user(email)
			if @cache.has_key?(email)
				return @cache[email]
			end

			search_uri = URI.parse("https://api.github.com/search/users?q=#{email}+in:email&per_page=1")
			search_response = Net::HTTP.get_response(search_uri)
			search_result = JSON.parse(search_response.body)

			if search_result['items'].empty?
				user = GithubUser.new('/images/unknown_user.png', nil)
			else
				user_item = search_result['items'][0]
				user = GithubUser.new(user_item['avatar_url'] + '&size=36', user_item['html_url'])
			end

			@cache[email] = user
		end
	end

	class SamplePage < Jekyll::Page
		def initialize(site, sample)
			@site = site
			@base = site.source
			@dir = File.dirname(sample.path)
			@name = "#{File.basename(sample.path)}.html"

			process(@name)
			read_yaml(File.join(@base, ''), '_sample.html')

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

		def initialize(sample_file_name, user_cache)
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

			@contributors = get_contributors(sample_file_name)
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

		private def get_contributors(file_name)
			real_path = file_name.split('/')[-3..-1].join('/')

			committers = nil
			Dir.chdir('_samples') do
				gitlog_output = `git log --follow --format="format:%ae %an" -- #{real_path}`
				committer_strings = gitlog_output.split("\n")
				committers = committer_strings.inject([]) do |committers, committer_string|
					split_committer_string = committer_string.split(/\s/,2)
					committers << {'email' => split_committer_string[0], 'name' => split_committer_string[1]}
				end
			end

			committers.uniq! {|committer| committer['email'] }

			contributors = []

			committers.each do |committer|
				user = @user_cache.get_user(committer['email'])

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
			Dir.chdir('_samples') do
				`git log -1 --format="format:%ad" -- #{real_path}`.strip
			end
		end
	end

	def self.build_samples_tree(samples_dir)
		sections = build_dir(samples_dir)

		user_cache = GithubUserCache.new

		sections.inject({}) do |tree, section|
			categories = build_dir(section.path)

			tree[section] = categories.inject({}) do |tree_section, category|
				tree_section[category] = collect_samples(category.path, user_cache)
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

	def self.collect_samples(dir, user_cache)
		sample_file_names = Dir.glob("#{dir}/*.cpp").sort
		sample_file_names.inject([]) do |samples, sample_file_name|
			samples << Sample.new(sample_file_name, user_cache)
		end
	end

	def self.get_random_sample(samples_tree)
		all_samples = []

		samples_tree.each do |_, sections|
			sections.each do |_, samples|
				all_samples.concat(samples)
			end
		end

		seed = Time.now.strftime("%U%Y").to_i + 5
		all_samples.sample(random: Random.new(seed))
	end
end
