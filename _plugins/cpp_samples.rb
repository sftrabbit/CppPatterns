module CppSamples
	class SamplesGenerator < Jekyll::Generator
		def generate(site)
			index = site.pages.detect { |page| page.url == '/index.html' }
		end
	end
end
