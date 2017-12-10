require 'net/http'
require 'uri'
require 'yaml'

module CppSamples
  DEFAULT_SAMPLES_DIR = 'samples'
  COMMENT_REGEX = /^\/\/\s*(.+)?$/
  SPECS = ['c++98', 'c++03', 'c++11', 'c++14', 'c++17', 'experimental']

  def self.sort_specs(specs)
    specs.sort {|spec1, spec2| SPECS.find_index(spec1) <=> SPECS.find_index(spec2)}
  end

  class SamplesGenerator < Jekyll::Generator
    def generate(site)
      index = site.pages.detect { |page| page.name == 'index.html' }

      samples_dir = site.config['samples_dir'] || DEFAULT_SAMPLES_DIR
      samples_tree = CppSamples::build_samples_tree(site, samples_dir)

      index.data['specs'] = SPECS
      index.data['sample_categories'] = samples_tree
      index.data['random_sample'] = CppSamples::get_random_sample(samples_tree)

      samples_tree.each do |category, samples|
        samples.each do |sample|
          sample.variations.keys.each do |spec|
            site.pages << SamplePage.new(site, sample, spec)
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
    def initialize(site, sample, spec)
      @site = site
      @base = site.source
      @dir = "samples/#{File.dirname(sample.name)}"

      is_primary = spec == sample.primary_spec

      if is_primary
        @name = "#{File.basename(sample.name)}.html"
      else
        @name = "#{File.basename(sample.name)}.#{spec}.html"
      end

      process(@name)
      read_yaml(File.join(@base, '_includes', ''), 'sample.html')

      variation = sample.variations[spec]

      self.data['sample'] = sample
      self.data['spec'] = spec
      self.data['title'] = variation.title
      self.data['description'] = variation.intent
    end
  end

  class Section
    attr_accessor :title

    def initialize(title)
      @title = title
    end

    def to_liquid
      return {'title' => @title}
    end
  end

  class Sample
    attr_accessor :name, :variations

    def initialize(samples_dir, sample_name, user_cache, contributors_list)
      @name = sample_name
      @user_cache = user_cache

      @variations = {}

      sample_paths = Dir.glob("#{samples_dir}/#{sample_name}*.cpp")
      sample_paths.each do |sample_path|
        spec_match = /^.+\.(?<spec>.+)\.cpp$/.match(sample_path)
        has_spec = !spec_match.nil?

        variation = Variation.new(sample_path, user_cache, contributors_list)

        spec = if has_spec
          spec_match['spec']
        else
          variation.tags[0] || 'c++98'
        end

        @variations[spec] = variation
      end
    end

    def primary
      @variations[primary_spec]
    end

    def min_spec
      CppSamples::sort_specs(@variations.keys).first
    end

    def primary_spec
      specs = CppSamples::sort_specs(@variations.keys)
      i = specs.rindex { |spec| spec.start_with?('c++') }
      specs[i] if i else specs.last
    end

    def to_liquid
      {
        'name' => @name,
        'primary' => primary.to_liquid,
        'min_spec' => min_spec,
        'primary_spec' => primary_spec,
        'variations' => @variations.each_with_object({}) do |(spec, variation), variations|
          variations[spec] = variation.to_liquid
          variations
        end
      }
    end
  end

  class Variation
    attr_accessor :file_name, :path, :code, :code_offset, :title, :intent, :tags, :description

    def initialize(sample_path, user_cache, contributors_list)
      @user_cache = user_cache

      sample_file = File.new(sample_path, 'r')

      @file_name = get_file_name(sample_path)
      @path = file_name_to_path(sample_path)

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

      @contributors = get_contributors(sample_path, contributors_list)
      @modified_date = get_modified_date(sample_path)
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
      real_path = file_name.split('/')[1..-1].join('/')

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
    if site.config['environment'] == "production"
      user_cache = GithubUserCache.new
    else
      user_cache = DummyUserCache.new
    end

    contributors_list = []
    File.open("#{samples_dir}/CONTRIBUTORS.txt", 'r').each_line do |line|
      match = /^\- ([^<>]*) (<(.*)> )?\((.*)\)\s*$/.match(line)
      contributors_list << {
        'name' => match[1],
        'email' => match[3],
        'github_username' => match[4]
      }
    end

    contents = YAML.load_file("#{samples_dir}/contents.yml")

    contents['categories'].each_with_object({}) do |category, tree|
      tree[Section.new(category['title'])] = category['samples'].map do |sample_path|
        Sample.new(samples_dir, sample_path, user_cache, contributors_list)
      end

      tree
    end
  end

  def self.get_random_sample(samples_tree)
    all_samples = []

    samples_tree.each do |_, samples|
      all_samples.concat(samples)
    end

    seed = Time.now.strftime("%U%Y").to_i
    all_samples.sample(random: Random.new(seed))
  end
end
