xml.svg(
  "xmlns" => "http://www.w3.org/2000/svg",
  "xmlns:xlink" => "http://www.w3.org/1999/xlink",
  "width" => @size,
  "height" => "#{@icons.count * @size}",
  "viewBox" => "0 0 #{@size} #{@icons.count * @size}"
) do
  @icons.each.with_index do |(id, path), index|
    xml.svg(
      "width" => "#{@size}",
      "height" => "#{@size}",
      "viewBox" => "0 0 24 24",
      "id" => "#{id}_#{@size}px",
      "y" => "#{index * @size}"
    ) do
      xml.path("d" => path)
    end
  end
end
