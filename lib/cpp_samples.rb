require 'pp'

require 'cpp_samples/version'

module CppSamples
	Section = Struct.new(:path, :title)
	Sample = Struct.new(:title, :code)

	SAMPLES_DIR = './samples'

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
			samples << extract_sample(sample_file_name)
		end
	end

	def self.extract_sample(sample_file_name)
		sample_file = File.new(sample_file_name, 'r')

		header = sample_file.readline
		header_match = /^\/\/\s*(.+)/.match(header)

		unless header_match
			raise "invalid header line in sample file: #{sample_file_name}"
		end

		title = header_match[1]

		code = sample_file.readlines.join().strip + "\n"

		Sample.new(title, code)
	end
end
