require 'pp'

module CppSamples
	DEFAULT_SAMPLES_DIR = '_samples'
	COMMENT_REGEX = /^\/\/\s*(.+)$/

	class SamplesGenerator < Jekyll::Generator
		def generate(site)
			index = site.pages.detect { |page| page.url == '/index.html' }

			samples_dir = site.config['samples_dir'] || DEFAULT_SAMPLES_DIR
			pp CppSamples::build_samples_tree(samples_dir)
		end
	end

	class Section
		attr_accessor :title, :path

		def initialize(title_file_name)
			@path = File.dirname(title_file_name)

			title_file = File.new(title_file_name, 'r')
			@title = title_file.readline.chomp
		end
	end

	class Sample
		attr_accessor :title, :code, :description

		def initialize(sample_file_name)
			sample_file = File.new(sample_file_name, 'r')

			sample_contents = strip_blank_lines(sample_file.readlines)

			@title = extract_title(sample_contents)
			description_lines = extract_description(sample_contents)
			description_start = sample_contents.length - description_lines.length
			@description = description_lines.join
			code_lines = strip_blank_lines(sample_contents[1..description_start-1])
			@code_lines = code_lines.join
		end

		private def extract_title(lines)
			header = lines[0]
			header_match = COMMENT_REGEX.match(header)

			unless header_match
				raise "invalid header line in sample"
			end

			header_match[1]
		end

		private def extract_description(lines)
			description = []
			line_index = lines.length - 1
			while match = COMMENT_REGEX.match(lines[line_index])
				description.unshift(match[1])
				line_index -= 1
			end
			description
		end

		private def strip_blank_lines(lines)
			lines.join("").strip.split("\n").map {|line| "#{line}\n" }
		end
	end

	def self.build_samples_tree(samples_dir)
		sections = build_dir(samples_dir)

		sections.inject({}) do |tree, section|
			categories = build_dir(section.path)

			tree[section] = categories.inject({}) do |tree_section, category|
				tree_section[category] = collect_samples(category.path)
				tree_section
			end

			tree
		end
	end

	def self.build_dir(dir)
		subdir_title_file_names = Dir.glob("#{dir}/*/TITLE")

		subdir_title_file_names.inject([]) do |sections, subdir_title_file_name|
			sections << Section.new(subdir_title_file_name)
		end
	end

	def self.collect_samples(dir)
		sample_file_names = Dir.glob("#{dir}/*.cpp")
		sample_file_names.inject([]) do |samples, sample_file_name|
			samples << Sample.new(sample_file_name)
		end
	end
end
