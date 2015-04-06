require 'jekyll/filters'

module CppSamples
	def self.generate_lineref_html(capital, line_start, line_end = nil)
		if line_end
			text = "lines #{line_start}&ndash;#{line_end}"
			end_attribute = "data-line-end=\"#{line_end}\""
		else
			text = "line #{line_start}"
			end_attribute = ""
		end

		text.capitalize! if capital

		return "<a href=\"#line#{line_start}\" class=\"lineref\" data-line=\"#{line_start}\" #{end_attribute}>#{text}</a>"
	end

	module SampleFilters
		include Jekyll::Filters

		def sample_markdown(text, code_offset)
			text.gsub!(/\[(\d+)\]/) do |match|
				line_num = $1.to_i - code_offset
				CppSamples::generate_lineref_html(false, line_num)
			end

			text.gsub!(/\[!(\d+)\]/) do |match|
				line_num = $1.to_i - code_offset
				CppSamples::generate_lineref_html(true, line_num)
			end

			text.gsub!(/\[(\d+)\-(\d+)\]/) do |match|
				line_num_start = $1.to_i - code_offset
				line_num_end = $2.to_i - code_offset
				CppSamples::generate_lineref_html(false, line_num_start, line_num_end)
			end

			text.gsub!(/\[!(\d+)\-(\d+)\]/) do |match|
				line_num_start = $1.to_i - code_offset
				line_num_end = $2.to_i - code_offset
				CppSamples::generate_lineref_html(true, line_num_start, line_num_end)
			end

			text.gsub!(/\[(.+?)\]\((c(pp)?\/.+?)\)/) do |match|
				"<a href=\"http://en.cppreference.com/w/#{$2}\">#{$1}</a>"
			end

			markdownify(text)
		end

		def sample_intent(sample)
			sample_markdown(sample['intent'], sample['code_offset'])
		end

		def sample_description(sample)
			sample_markdown(sample['description'], sample['code_offset'])
		end
	end
end

Liquid::Template.register_filter(CppSamples::SampleFilters)
