module Atua
  Download = Data.define(:report_type, :start_date, :end_date, :content, :content_type, :filename) do
    def size
      content.bytesize
    end

    def inspect
      "#<#{self.class.name} report_type=#{report_type.inspect} start_date=#{start_date.inspect} end_date=#{end_date.inspect} " \
        "content_type=#{content_type.inspect} filename=#{filename.inspect} size=#{size}>"
    end
  end
end
