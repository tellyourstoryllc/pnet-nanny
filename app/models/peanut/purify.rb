module Peanut
  class Purify

    class << self

      def cleanse(text)
        pattern = /\b(#{self.dictionary.join('|')})\b/i
        canonize(text).gsub(pattern, '****')
      end

      def score(text)
        pattern = /(#{self.dictionary.join('|')})/i
        text.scan(pattern).count 
      end

      def canonize(text)
        begin
          new_text = text
          new_text.gsub!(/[\s]+/i, ' ')

          pattern = /((\s|^)(\S(\s|\W|$)){2,})/i
          matches = new_text.scan(pattern)
          matches.each do |m|
            original = m[0]
            replacement = original.gsub(/\s/,'')
            new_text.gsub!(Regexp.escape(original), " #{replacement} ")
          end        

          new_text = self.reduce(new_text)
          self.aliases.each { |orig, repl| new_text.gsub!(/(\b|^)#{orig}(\b|$)/i, '\1'+repl+'\2') }  

          new_text.strip
        rescue Exception=>ex
          text.strip if text
        end
      end

      def reduce(text)
        reduced_text = text.clone
        self.reductions.each { |orig, repl| reduced_text.gsub!(orig, repl) }
        if reduced_text == text
          return reduced_text 
        else
          return reduce(reduced_text)
        end
      end
      
      def dictionary
        d = []
        d << 'fuck'
        d << 'fuk'
        d << 'shit'
        d << 'piss'
        d << 'horny'
        d << 'horney'
        d << 'cock'
        d << 'dick'
        d << 'cum'
        d << 'ass'
        d << 'pussy'
        d << 'lesbian'
        d << 'lezbian'
        d << 'lezbo'
        d << 'lez'
        d << 'les'
        d << 'clit'
        d << 'cunt'
        d << 'itunes card'
        d << 'itunes'
        d << 'paypal'
        d << 'xbox'
        d << 'nude'
        d << 'young girl'
        d << 'knocking'
        d << 'fucking'
        d << 'tit'
        d << 'titty'
        d << 'boob'
        d << 'phone sex'
        d << 'vagina'
        d << 'penis'
        d << 'pedo'
        d << 'pedophile'
        d << 'nigger'
        d << 'pic for pic'
        d << 'trade pic'
        d << 'pic trade'
        d << 'bj'
        d << 'blowjob'
        d << 'slut'
        d << 'whore'
        d << 'incest'
        
        d + d.reject { |word| word[-1,1] == 's' }.map { |word| "#{word}s" }
      end

      def reductions
        a = {}
        a['yy'] = 'y'
        a['zzz'] = 'zz'
        a['00'] = 'oo'
        a['$$'] = 'ss'
        a
      end
      
      def aliases
        a = {}
        a['azz'] = 'ass'
        a['frack'] = 'fuck'
        a['fukk'] = 'fuck'
        a
      end

    end
  end
end