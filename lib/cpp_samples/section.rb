module CppSamples
	class Section
		attr_accessor :title, :path

		def initialize(title_file_name)
			@path = File.dirname(title_file_name)

			title_file = File.new(title_file_name, 'r')
			@title = title_file.readline.chomp
		end
	end
end
