require 'nokogiri'
require 'nkf'
require 'shoes/version'
require 'shoes/highlighter'
require 'shoes/manual'

Shoes.app :width => 1200, :height => 900, :resizable => true, :title => "Ruby-Shoe Editor 1.0" do
  flow :margin => 10 do
    button "Open", :width => 75 do
      @file = ask_open_file
      @edit.text = File.read(@file)
      @filename.text = @file
    end

    button "Save", :width => 75 do
      File.open(@file, "w+") do |f|
        f.write @edit.text
      end
    end
    button "SaveAs", :width => 85 do
      file = ask_save_file
      File.open(file, "w+") do |f|
        f.write @edit.text
      end
    end
    button "Close", :width => 75 do
      close()
    end
    button "Bkgd" do
      color = ask_color("Sanday says 'pick a new background color'")
      background color
    end
  end
  @edit = edit_box :margin_left => 130, :width => "100%", :height => 750
  @filename = para ""
  @filename.style(:align => 'center')

end