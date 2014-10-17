module Sabrina
  # Current software version.
  #
  # @return [String]
  VERSION = '0.5.6'

  # Date of the current version.
  #
  # @return [String]
  DATE = '2014-10-13'

  # A short description.
  #
  # @return [String]
  ABOUT = 'Hack GBA ROMs of a popular monster collection RPG series.'

  class << self
    # Gets the PNG handler info.
    def png
      PNG
    end

    # @see VERSION
    def version
      "#{VERSION}/#{PNG}"
    end

    # @see ABOUT
    def about
      ABOUT
    end
  end
end
