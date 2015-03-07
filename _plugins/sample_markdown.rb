require 'jekyll/filters'

module CppSamples
	module SampleFilters
		include Jekyll::Filters

		def sample_description(sample)
			description = sample['description']

			description.gsub!(/\[(\d+)\]/) do |match|
				line_num = $1.to_i - sample['code_offset']
				"<span class=\"lineref\" data-line=\"#{line_num}\">line #{line_num}</span>"
			end

			description.gsub!(/\[(\d+)\-(\d+)\]/) do |match|
				line_num_start = $1.to_i - sample['code_offset']
				line_num_end = $2.to_i - sample['code_offset']
				"<span class=\"lineref\" data-line=\"#{line_num_start}\" data-line-end=\"#{line_num_end}\">lines #{line_num_start}&ndash;#{line_num_end}</span>"
			end

			description.gsub!(/\[(.+?)\]\((c(pp)?\/.+?)\)/) do |match|
				"<a href=\"http://en.cppreference.com/w/#{$2}\">#{$1}</a>"
			end

			markdownify(description)
		end

		def sample_excerpt(sample)
			description = sample['description']
			blank_line_index = /\n[\t ]*\n/ =~ description

			if blank_line_index
				return markdownify(description[0..blank_line_index])
			end

			markdownify(description)
		end
	end
end

Liquid::Template.register_filter(CppSamples::SampleFilters)
