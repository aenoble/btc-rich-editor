require 'cgi'
require 'mime/types'

module Rich
  class RichFile < ActiveRecord::Base
    
    scope :images, where("rich_rich_files.simplified_type = 'image'")
    scope :files, where("rich_rich_files.simplified_type = 'file'")
    
    paginates_per 27
    
    has_attached_file :rich_file, :styles => Proc.new {|a| a.instance.set_styles }
    
    validates_attachment_presence :rich_file
    validate :check_content_type
    validates_attachment_size :rich_file, :less_than=>15.megabyte, :message => "must be smaller than 15MB"
    
    before_create :clean_file_name

    after_create :cache_style_uris_and_save
    before_update :cache_style_uris
    
    def image?
      Rich.simplified_type_for(MIME::Types.type_for(rich_file_file_name)[0].content_type) == "image"
    end
    
    def set_styles
      if image?
        Rich.image_styles
      else
        {}
      end
    end
    
    private
    
    def cache_style_uris_and_save
      cache_style_uris
      self.save!
    end
    
    def cache_style_uris
      uris = {}
      
      rich_file.styles.each do |style|
        uris[style[0]] = rich_file.url(style[0].to_sym)
      end
      
      # manualy add the original size
      uris["original"] = rich_file.url(:original)
      
      self.uri_cache = uris.to_json
    end
    
    def clean_file_name      
      extension = File.extname(rich_file_file_name).gsub(/^\.+/, '')
      filename = rich_file_file_name.gsub(/\.#{extension}$/, '')
      
      filename = CGI::unescape(filename)
      filename = CGI::unescape(filename)
      
      extension = extension.downcase
      filename = filename.downcase.gsub(/[^a-z0-9]+/i, '-')
      
      self.rich_file.instance_write(:file_name, "#{filename}.#{extension}")
    end
    
    def check_content_type
      self.rich_file.instance_write(:content_type, MIME::Types.type_for(rich_file_file_name)[0].content_type)
      self.simplified_type = Rich.simplified_type_for(self.rich_file_content_type)
      
      unless Rich.is_allowed_type(self.simplified_type)
        self.errors[:base] << "'#{self.rich_file_file_name}' is not the right type."
      end
    end
    
  end
end
