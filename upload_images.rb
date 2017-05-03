require 'net/http'

class UploadImage

  def initialize pwd
    @pwd = pwd[0]
    @metadata_rows = {title: nil, subject_id: nil, shoot_num: nil, date: nil}
    @allow_image_extension = ['JPEG','JPG','jpg', 'jpeg', 'png']
    @images = []
  end

  def parse_process
    get_metadata_file

    get_images_from_folder

    upload_image_to_s3

    send_request_to_server
  end

  def upload_image_to_s3
    `s3cmd sync #{@pwd}/ s3://thefemalenude/#{@directory}`

    delete_not_image_file if @not_images.any?

    p "#{@images.count} images uploaded to s3"
  end

  def get_metadata_file
    begin
      metadata = File.open("#{@pwd}/metadata.txt").read

      parse_metadata_file(metadata)

      сheck_for_missing_attribute

      @directory = "tmp_folder/#{@metadata_rows[:shoot_num]}/"

    rescue Exception => e
      p "Please, put correct metadata file into your directory: #{@pwd}"
    end
  end

  def parse_metadata_file metadata
    m_array = metadata.split(/\n/)
    m_array.each do |row|
      @metadata_rows.keys.each do |mdr|
        row.scan(/#{mdr.to_s}:/).any? ? @metadata_rows[mdr] = row.gsub(/#{mdr.to_s}:/, '').strip : nil
      end
    end
  end

  def сheck_for_missing_attribute
    begin
      @metadata_rows.each{|k,v| v.nil? ? raise("Please, specify '#{k.to_s}' in metadata.txt") : true}
    rescue Exception => e
      p e
    end
  end

  def get_images_from_folder
    @allow_image_extension.each do |ext|
      @images = @images + (Dir["#{@pwd}/*.#{ext}"])
    end
    @not_images = Dir["#{@pwd}/*", "#{@pwd}/.*"] - @images
  end

  def delete_not_image_file
    @not_images.each do |ni|
      name = ni.split(/\//).last
      unless name == '.' || name == '..'
        `s3cmd del s3://thefemalenude/#{@directory}#{name}`
      end
    end
  end

  def send_request_to_server
    params = {
        shoot_num:    @metadata_rows[:shoot_num],
        subject_id:   @metadata_rows[:subject_id],
        date:         @metadata_rows[:date],
        title:        @metadata_rows[:title],
        directory: @directory
    }
    Net::HTTP.post_form(URI.parse('http://thefemalenude.org/save_images'), params)
  end

end


UploadImage.new(ARGV).parse_process