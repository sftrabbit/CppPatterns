require 'jekyll/filters'

module CppSamples
	module SampleFilters
		include Jekyll::Filters

		def sample_markdown(text, code_offset)
			text.gsub!(/\[(\d+)\]/) do |match|
				line_num = $1.to_i - code_offset
				"<a href=\"#line#{line_num}\" class=\"lineref\" data-line=\"#{line_num}\">line #{line_num}</a>"
			end

			text.gsub!(/\[!(\d+)\]/) do |match|
				line_num = $1.to_i - code_offset
				"<a href=\"#line#{line_num}\" class=\"lineref\" data-line=\"#{line_num}\">Line #{line_num}</a>"
			end

			text.gsub!(/\[(\d+)\-(\d+)\]/) do |match|
				line_num_start = $1.to_i - code_offset
				line_num_end = $2.to_i - code_offset
				"<a href=\"#line#{line_num_start}\" class=\"lineref\" data-line=\"#{line_num_start}\" data-line-end=\"#{line_num_end}\">lines #{line_num_start}&ndash;#{line_num_end}</a>"
			end

			text.gsub!(/\[!(\d+)\-(\d+)\]/) do |match|
				line_num_start = $1.to_i - code_offset
				line_num_end = $2.to_i - code_offset
				"<a href=\"#line#{line_num_start}\" class=\"lineref\" data-line=\"#{line_num_start}\" data-line-end=\"#{line_num_end}\">Lines #{line_num_start}&ndash;#{line_num_end}</a>"
			end

			text.gsub!(/\[(.+?)\]\((c(pp)?\/.+?)\)/) do |match|
				"<a href=\"http://en.cppreference.com/w/#{$2}\">#{$1}</a>"
			end

			markdownify(text)
		end

		def sample_intent(sample)
			sample_markdown(sample['intent'],  sample['code_offset'])
		end

		def sample_description(sample)
			sample_markdown(sample['description'],  sample['code_offset'])
		end
	end
end

Liquid::Template.register_filter(CppSamples::SampleFilters)
