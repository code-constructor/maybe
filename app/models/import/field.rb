class Import::Field
  def self.iso_date_validator(value)
    Date.parse(value)
    true
  rescue
    false
  end

  def self.bigdecimal_validator(value)
    BigDecimal(value)
    true
  rescue
    false
  end

  def self.bigdecimal_preprocessor(value)
    value.gsub(",", ".")
  end

  attr_reader :key, :label, :validator, :preprocessor

  def initialize(key:, label:, is_optional: false, validator: nil, preprocessor: nil)
    @key = key.to_s
    @label = label
    @is_optional = is_optional
    @validator = validator
    @preprocessor = preprocessor
  end

  def optional?
    @is_optional
  end

  def define_validator(validator = nil, &block)
    @validator = validator || block
  end

  def define_preprocessor(preprocessor = nil, &block)
    @preprocessor = preprocessor || block
  end

  def validate(value)
    return true if validator.nil?
    value = preprocessor.call(value) if preprocessor
    validator.call(value)
  end
end
