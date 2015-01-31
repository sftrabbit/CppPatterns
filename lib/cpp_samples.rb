require 'pp'

require 'cpp_samples/version'

module CppSamples
	Section = Struct.new(:path, :title)
	Sample = Struct.new(:title, :code, :description)

	SAMPLES_DIR = './samples'
	COMMENT_REGEX = /^\/\/\s*(.+)$/

	def self.generate
		pp build_samples_tree(SAMPLES_DIR)
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
			subdir_path = File.dirname(subdir_title_file_name)

			subdir_title_file = File.new(subdir_title_file_name, 'r')
			subdir_title = subdir_title_file.readline.chomp

			sections << Section.new(subdir_path, subdir_title)
		end
	end

	def self.collect_samples(dir)
		sample_file_names = Dir.glob("#{dir}/*.cpp")
		sample_file_names.inject([]) do |samples, sample_file_name|
			samples << read_sample(sample_file_name)
		end
	end

	def self.read_sample(sample_file_name)
		sample_file = File.new(sample_file_name, 'r')

		sample_contents = strip_blank_lines(sample_file.readlines)

		title = extract_title(sample_contents)
		description = extract_description(sample_contents)
		description_start = sample_contents.length - description.length
		code = strip_blank_lines(sample_contents[1..description_start-1])

		Sample.new(title, code, description)
	end

	def self.extract_title(lines)
		header = lines[0]
		header_match = COMMENT_REGEX.match(header)

		unless header_match
			raise "invalid header line in sample"
		end

		header_match[1]
	end

	def self.extract_description(lines)
		description = []
		line_index = lines.length - 1
		while match = COMMENT_REGEX.match(lines[line_index])
			description.unshift(match[1])
			line_index -= 1
		end
		description
	end

	def self.strip_blank_lines(lines)
		lines.join("").strip.split("\n").map {|line| "#{line}\n" }
	end
end
