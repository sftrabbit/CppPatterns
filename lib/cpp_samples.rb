require 'pp'

require 'cpp_samples/version'
require 'cpp_samples/tree'

module CppSamples
	SAMPLES_DIR = './samples'

	def self.generate
		pp build_samples_tree(SAMPLES_DIR)
	end
end
