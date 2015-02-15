require 'jekyll/filters'

module CppSamples
	module SampleMarkdownFilter
		include Jekyll::Filters

		def sample_description(sample)
			description = sample['description']
			description.gsub!(/\[(\d+)\]/) do |match|
				line_num = $1.to_i - sample['code_offset']
				"<span class=\"lineref\" data-line=\"#{line_num}\">line #{line_num}</span>"
			end
			markdownify(description)
		end
	end
end

Liquid::Template.register_filter(CppSamples::SampleMarkdownFilter)
