#!/usr/bin/env ruby
# encoding: utf-8

require 'prawn/table'
require 'prawn'
require 'date'
require 'faker'
require 'pry'

# disable warning relative a built-in fonts
Prawn::Font::AFM.hide_m17n_warning = true

def format_currency(currency)
  format('%5.2f', currency) + '€'
end

EVERY_PAGE_LINES = 30
LAST_PAGE_LINES = 21
DEFAULT_ITEM_COUNT = 75
TOTAL_ITEMS = ARGV[0]&.to_i || DEFAULT_ITEM_COUNT # pass total items as an optional parameter

def calc_this_page_lines(line_count)
  remainder = TOTAL_ITEMS % EVERY_PAGE_LINES
  if line_count < (TOTAL_ITEMS - remainder)
    EVERY_PAGE_LINES
  else
    LAST_PAGE_LINES
  end
end

@sum_units = 0
@sum_total = 0
@items = (1..TOTAL_ITEMS).map do |i|
  units = rand(21) + 1
  price = Faker::Commerce.price
  total = units * price
  @sum_units += units
  @sum_total += total
  [
    '5600300' + format('%05d', rand(100_000)),
    "BN5001.#{format('%03d', i)}",
    Faker::Commerce.product_name,
    units,
    format_currency(price),
    format_currency(total)
  ]
end

@pdf = Prawn::Document.new
@pdf.font 'Helvetica'

@page_counter = 1
def customer_info
  # Defining the grid
  # See http://prawn.majesticseacreature.com/manual.@pdf
  @pdf.define_grid(columns: 5, rows: 8, gutter: 10)

  @pdf.grid([0, 0], [1, 1]).bounding_box do
    @pdf.text 'INVOICE', size: 18
    @pdf.text 'Invoice No: 0001', align: :left
    @pdf.text "Date: #{Time.now}", align: :left
    @pdf.move_down 10

    @pdf.text 'Attn: To whom it may concern '
    @pdf.text 'Company Name'
    @pdf.text 'Tel No: 1'
    @pdf.text "Page #{@page_counter}"
    @pdf.move_down 10
  end
end

def issuer_info
  @pdf.grid([0, 3.6], [1, 4]).bounding_box do
    # Assign the path to your file name first to a local variable.
    logo_path = File.expand_path('../../image/gravatar.jpg', __FILE__)

    # Displays the image in your PDF. Dimensions are optional.
    @pdf.image logo_path, width: 50, height: 50, position: :left

    # Company address
    @pdf.move_down 10
    @pdf.text 'Awesomeness Ptd Ltd', align: :left
    @pdf.text 'Address', align: :left
    @pdf.text 'Street 1', align: :left
    @pdf.text '40300 Shah Alam', align: :left
    @pdf.text 'Selangor', align: :left
    @pdf.text 'Tel No: 42', align: :left
    @pdf.text 'Fax No: 42', align: :left
  end
end

def page_header
  customer_info
  issuer_info

  @pdf.text 'Details of Invoice', style: :bold_italic
  @pdf.stroke_horizontal_rule
end

def report_footer
  @pdf.bounding_box([0, @pdf.bounds.bottom + 200], width: 550, height: 200) do
    @pdf.move_down 40
    @pdf.text 'Terms & Conditions of Sales'
    @pdf.text "1.\tAll cheques should be crossed and made payable to Awesomeness Ptd Ltd"

    @pdf.move_down 40
    @pdf.text 'Received in good condition', style: :italic

    @pdf.move_down 20
    @pdf.text '...............................'
    @pdf.text 'Signature/Company Stamp'

    @pdf.move_down 10
    @pdf.stroke_horizontal_rule
  end
end

#
# main loop
#
item_count = 0
loop do
  @pdf.start_new_page unless item_count == 0
  page_header
  @this_page_lines = calc_this_page_lines(item_count)
  page_items = @items[item_count..item_count + (@this_page_lines - 1)].insert(0, %w(Code Ref Description Units Price Total))
  item_count += @this_page_lines
  page_items.push(['', '', 'TOTAL INVOICE', @sum_units, '', format_currency(@sum_total)]) if item_count >= TOTAL_ITEMS
  @page_counter += 1
  @pdf.table(page_items, header: true, width: 550, cell_style: { size: 8, height: 17, borders: [:left, :right] }) do |t|
    t.columns(3..5).align = :right
    # t.cells.style do |cell|
    #   cell.height = 12
    #   cell.style[:size] = 10
    # end
    t.row(0).style text_color: 'FFFFFF', background_color: '000000', borders: [:left, :right, :top]
    t.rows(t.row_length - 1).style borders: [:left, :right, :bottom]
  end
  break if item_count >= TOTAL_ITEMS
end
if @this_page_lines > LAST_PAGE_LINES
  @pdf.start_new_page
  page_header
end
report_footer

@pdf.render_file 'invoice.pdf'
