module Yap
  module Cli
    module Console
      class Printer
        def initialize(data)
          @data = data
        end

        def print_table
          return if @data.empty?
          number_of_columns = @data.first.length
          column_widths = Hash.new { |h,k| h[k] = 0 }
          number_of_columns.times do |i|
            column_widths[i] = @data.map { |row| row[i].length }.max
          end
          @data.each do |row|
            row.each_with_index do |cell, i|
              printf("%-#{column_widths[i]}s  ", cell)
            end
            puts
          end
        end
      end
    end
  end
end
