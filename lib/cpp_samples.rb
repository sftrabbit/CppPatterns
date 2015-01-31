require 'pp'

require 'cpp_samples/version'

module CppSamples
	Section = Struct.new(:path, :title)

	SAMPLES_DIR = './samples'

	def self.generate
		pp build_samples_tree(SAMPLES_DIR)
	end

	def self.build_samples_tree(samples_dir)
		sections = build_dir(samples_dir)

		sections.inject({}) do |tree, section|
			categories = build_dir(section.path)

			tree[section] = categories.inject({}) do |tree_section, category|
				tree_section[category] = []
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
			subdir_title = subdir_title_file.readline

			sections << Section.new(subdir_path, subdir_title)
		end
	end
end
