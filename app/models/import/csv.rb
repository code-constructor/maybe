class Import::Csv
  DEFAULT_COL_SEP = ",".freeze

  def self.parse_csv(csv_str, col_sep: DEFAULT_COL_SEP)
    CSV.parse((csv_str || "").strip, headers: true, col_sep:, liberal_parsing: true, converters: [ ->(str) { str&.strip } ])
  end

  def self.create_with_field_mappings(raw_csv_str, col_sep, fields, field_mappings)
    raw_csv = self.parse_csv(raw_csv_str, col_sep:)

    generated_csv_str = CSV.generate col_sep:, headers: fields.map { |f| f.key }, write_headers: true do |csv|
      raw_csv.each do |row|
        row_values = []

        fields.each do |field|
          # Finds the column header name the user has designated for the expected field
          mapped_field_key = field_mappings[field.key] if field_mappings
          mapped_header = mapped_field_key || field.key

          row_values << row.fetch(mapped_header, "")
        end

        csv << row_values
      end
    end

    new(generated_csv_str, col_sep:)
  end

  attr_reader :csv_str
  attr_reader :col_sep

  def initialize(csv_str, column_validators: nil, column_preprocessors: nil, col_sep: DEFAULT_COL_SEP)
    @csv_str = csv_str
    @col_sep = col_sep
    @column_validators = column_validators || {}
    @column_preprocessors = column_preprocessors || {}
  end

  def table
    @table ||= self.class.parse_csv(csv_str, col_sep: col_sep).tap do |table|
      table.each do |row|
        row["amount"] = get_preprocessor_by_header("amount").call(row["amount"])
      end
    end
  end

  def update_cell(row_idx, col_idx, value)
    copy = table.by_col_or_row

    preprocessor = get_preprocessor_by_header(header)

    copy[row_idx][col_idx] = preprocessor.call(value)
    copy
  end

  def valid?
    table.each_with_index.all? do |row, row_idx|
      row.each_with_index.all? do |cell, col_idx|
        cell_valid?(row_idx, col_idx)
      end
    end
  end

  def cell_valid?(row_idx, col_idx)
    value = table.dig(row_idx, col_idx)
    header = table.headers[col_idx]
    preprocessor = get_preprocessor_by_header(header)
    validator = get_validator_by_header(header)
    validator.call(preprocessor.call(value))
  end

  def define_validator(header_key, validator = nil, &block)
    header = table.headers.find { |h| h.strip == header_key }
    raise "Cannot define validator for header #{header_key}: header does not exist in CSV" if header.nil?

    column_validators[header] = validator || block
  end

  def define_preprocessor(header_key, preprocessor = nil, &block)
    header = table.headers.find { |h| h.strip == header_key }
    raise "Cannot define preprocessor for header #{header_key}: header does not exist in CSV" if header.nil?

    column_preprocessors[header] = preprocessor || block

    # reset table caching
    @table = nil
  end

  private

    attr_accessor :column_validators
    attr_accessor :column_preprocessors

    def get_validator_by_header(header)
      column_validators&.dig(header) || ->(_v) { true }
    end

    def get_preprocessor_by_header(header)
      column_preprocessors&.dig(header) || ->(v) { v }
    end
end
