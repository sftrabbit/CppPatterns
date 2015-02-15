require 'jekyll/filters'

module CppSamples
	module SampleMarkdownFilter
		include Jekyll::Filters

		def sample_markdown(input)
			markdownify(input)
		end
	end
end

Liquid::Template.register_filter(CppSamples::SampleMarkdownFilter)
