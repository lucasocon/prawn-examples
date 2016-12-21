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

EVERY_PAGE_LINES = 43
LAST_PAGE_LINES = 35
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
    Faker::Commerce.product_name.upcase,
    units,
    format_currency(price),
    format_currency(total)
  ]
end
@total_pages = if (TOTAL_ITEMS >= EVERY_PAGE_LINES) && (TOTAL_ITEMS % EVERY_PAGE_LINES > LAST_PAGE_LINES)
                 (TOTAL_ITEMS.to_f / EVERY_PAGE_LINES).round + 1
               elsif TOTAL_ITEMS > LAST_PAGE_LINES
                 2
               else
                 1
               end

@issuer = {
  name: Faker::Company.name,
  street_name: Faker::Address.street_name,
  zip_city: Faker::Address.zip + ' ' + Faker::Address.city,
  ein: Faker::Company.ein,
  phone_number: Faker::PhoneNumber.phone_number,
  email: Faker::Internet.email,
  url: Faker::Internet.url
}

@customer = {
  name: Faker::Company.name,
  street_name: Faker::Address.street_name,
  zip_city: Faker::Address.zip + ' ' + Faker::Address.city,
  ein: Faker::Company.ein,
  phone_number: Faker::PhoneNumber.phone_number,
  email: Faker::Internet.email,
  url: Faker::Internet.url
}

@invoice = {
  no: '2/000042',
  date: Date.today.to_s,
  customer: '11032',
  customer_ein: @customer[:ein]
}

@pdf = Prawn::Document.new
@pdf.font 'Helvetica'
@page_counter = 1

def issuer_info
  @pdf.bounding_box([0, @pdf.cursor], width: 550) do
    @pdf.text @issuer[:name], size: 20
    @pdf.font_size 8
    @pdf.text @issuer[:street_name]
    @pdf.text @issuer[:zip_city]
    @pdf.text @issuer[:ein]
    @pdf.text @issuer[:phone_number]
    @pdf.text @issuer[:email]
    @pdf.text @issuer[:url]
    @pdf.move_down 10
  end
end

def invoice_info
  @saved_cursor = @pdf.cursor
  @invoice[:page] = "#{@page_counter} / #{@total_pages}"
  @page_counter += 1
  info = @invoice.map { |k, v| [k.to_s, v] }
  @pdf.table(info,
             header: false,
             width: 200,
             cell_style: { size: 8, height: 12, padding: [0, 4, 0, 4] }) do |t|
    t.columns(0).style borders: [:left, :top, :bottom]
    t.columns(1).style borders: [:right, :top, :bottom]
    t.columns(1).align = :right
    t.row(0).style font_style: :bold
  end
  @pdf.move_down 10
end

def customer_info
  @pdf.stroke_color 'FFFFFF'
  @pdf.stroke_bounds
  @pdf.stroke do
    @pdf.stroke_color '000000'
    @pdf.fill_color 'FFFFFF'
    @pdf.fill_and_stroke_rounded_rectangle [250, @pdf.cursor + 105], 300, 90, 10
  end

  @pdf.bounding_box([260, @saved_cursor + 25], width: 300) do
    @pdf.fill_color '000000'
    @pdf.text @customer[:name], size: 16
    @pdf.font_size 12
    @pdf.text @customer[:street_name]
    @pdf.text @customer[:zip_city]
    @pdf.text @customer[:ein]
    @pdf.text @customer[:phone_number]
    @pdf.move_down 20
  end
end

def page_header
  issuer_info
  invoice_info
  customer_info
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
  unless item_count == 0
    @pdf.move_down 5
    @pdf.bounding_box([400, @pdf.cursor], width: 150) do
      @pdf.text 'Continue ...', size: 16, font_style: :bold
    end
    @pdf.start_new_page
  end
  page_header
  @this_page_lines = calc_this_page_lines(item_count)
  page_items = @items[item_count..item_count + (@this_page_lines - 1)].insert(0, %w(Code Ref Description Units Price Total))
  item_count += @this_page_lines
  # page_items.push(['', '', 'TOTAL INVOICE', @sum_units, '', format_currency(@sum_total)]) if item_count >= TOTAL_ITEMS
  @pdf.table(page_items,
             header: true,
             width: 550,
             cell_style: { size: 8, height: 12, borders: [:left, :right], padding: [0, 4, 0, 4] }) do |t|
    t.columns(3..5).align = :right
    t.row(0).columns(3..5).align = :left
    t.row(0).style text_color: 'FFFFFF', background_color: '000000', borders: [:left, :right, :top]
    t.rows(-1).style borders: [:left, :right, :bottom]
  end
  break if item_count >= TOTAL_ITEMS
end
if @this_page_lines > LAST_PAGE_LINES
  @pdf.start_new_page
  page_header
end
report_footer

@pdf.render_file 'invoice.pdf'
