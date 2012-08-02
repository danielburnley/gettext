# encoding: utf-8

=begin
  rmsginit.rb - Initialize .pot with metadata and create .po

  Copyright (C) 2012 Haruka Yoshihara

  You may redistribute it and/or modify it under the same
  license terms as Ruby or LGPL.
=end

require 'gettext'
require 'locale/info'
require 'rbconfig'
require 'optparse'

module GetText
  module RMsgInit
    extend GetText
    extend self

    bindtextdomain "rgettext"

    def run(*options)
      input_file, output_file, locale = check_options(*options)

      pot_contents = File.read(input_file)
      po_contents = replace_pot_header(pot_contents, locale)

      File.open(output_file, "w") do |f|
        f.puts(po_contents)
      end

      self
    end

    def check_options(*options)
      input_file, output_file, locale = parse_arguments(*options)

      if input_file.nil?
        input_file = Dir.glob("./*.pot").first
        if input_file.nil?
          raise(_(".pot file does not exist in current directory."))
        end
      else
        unless File.exist?(input_file)
          raise(_("file #{input_file} does not exist."))
        end
      end

      locale ||= Locale.current.to_s

      output_file ||= "#{locale}.po"
      if File.exist?(output_file)
        raise(_("file #{output_file} has already existed."))
      end

      [input_file, output_file, locale]
    end

    VERSION = GetText::VERSION
    DATE = "2012/07/30"

    def parse_arguments(*options) #:nodoc:
      input_file = nil
      output_file = nil
      locale = nil

      parser = OptionParser.new
      parser.banner = "Usage: #{$0} [OPTION]"
      options_description =
_(<<EOD
Initialize a .pot file with user's environment and input and create a .po
file from an initialized .pot file.
A .pot file is specified as input_file. If input_file is not
specified, a .pot file existing current directory is used. A .po file is
created from initialized input_file as output_file. if output_file
isn't specified, output_file is "locale.po". If locale is not
specified, the current locale is used.
EOD
)
      parser.separator(options_description)
      parser.separator("")
      parser.separator(_("Specific options:"))

      parser.on("-i", "--input=FILE",
                _("read input from specified file")) do |input|
        input_file = input
      end

      parser.on("-o", "--output=FILE",
                _("write output to specified file")) do |output|
        output_file = output
      end

      parser.on("-l", "--locale=LOCALE",
                _("locale used with .po file")) do |loc|
        locale = loc
      end

      parser.on("-h", "--help",
                _("dispray this help and exit")) do
        puts(parser.help)
        exit(true)
      end

      parser.on_tail("--version",
                     _("display version information and exit")) do
        puts("#{$0} #{VERSION} (#{DATE})")
        ruby_bin_dir = ::RbConfig::CONFIG["bindir"]
        ruby_install_name = ::RbConfig::CONFIG["RUBY_INSTALL_NAME"]
        ruby_description = "#{File.join(ruby_bin_dir, ruby_install_name)} " +
                             "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) " +
                             "[#{RUBY_PLATFORM}]"
        puts(ruby_description)
        exit(true)
      end

      parser.parse!(options)

      [input_file, output_file, locale]
    end

    DESCRIPTION_TITLE = /^(\s*#\s*) SOME DESCRIPTIVE TITLE\.$/

    def replace_pot_header(pot, locale)
      pot = replace_description(pot, locale)
      pot = replace_translators(pot)
      pot = replace_date(pot)
      pot = replace_language(pot, locale)
      pot = replace_plural_forms(pot, locale)
      pot.gsub(/#, fuzzy\n/, "")
    end

    def replace_description(pot, locale)
      language_name = Locale::Info.get_language(locale.to_s).name
      description = "#{language_name} translations for PACKAGE package."

      pot.gsub(DESCRIPTION_TITLE, "\\1 #{description}")
    end

    EMAIL = "<EMAIL@ADDRESS>"
    FIRST_AUTHOR_KEY = /^(\s*#\s*) FIRST AUTHOR #{EMAIL}, YEAR\.$/
    LAST_TRANSLATOR_KEY = /^(\"Last-Translator:) FULL NAME #{EMAIL}\\n"$/

    def replace_translators(pot) #:nodoc:
      fullname, mail = get_translator_metadata
      year = Time.now.year
      pot = pot.gsub(FIRST_AUTHOR_KEY, "\\1 #{fullname} <#{mail}>, #{year}.")
      pot.gsub(LAST_TRANSLATOR_KEY, "\\1 #{fullname} <#{mail}>\\n\"")
    end

    def get_translator_metadata
      logname = ENV["LOGNAME"] || `whoami`
      if /Name: (.+)/ =~ `finger #{logname}`
        fullname = $1
      else
        fullname = logname
      end

      puts("Please enter your email address.")
      mail = STDIN.gets.chomp
      if mail.empty?
        hostname = `hostname`.chomp
        mail = "#{logname}@#{hostname}"
      end

      [fullname, mail]
    end

    POT_REVISION_DATE_KEY = /^("PO-Revision-Date:).+\\n"$/
    COPYRIGHT_KEY = /(# Copyright \(C\)) YEAR (THE PACKAGE'S COPYRIGHT HOLDER)$/

    def replace_date(pot) #:nodoc:
      date = Time.now
      revision_date = date.strftime("%Y-%m-%d %H:%M%z")

      pot = pot.gsub(POT_REVISION_DATE_KEY, "\\1 #{revision_date}\\n\"")
      pot.gsub(COPYRIGHT_KEY, "\\1 #{date.year} \\2")
    end

    LANGUAGE_KEY = /^("Language:).+\\n"$/
    LANGUAGE_TEAM_KEY = /^("Language-Team:).+\\n"$/

    def replace_language(pot, locale) #:nodoc:
      pot = pot.gsub(LANGUAGE_KEY, "\\1 #{locale}\\n\"")

      language_name = Locale::Info.get_language(locale.to_s).name
      pot.gsub(LANGUAGE_TEAM_KEY, "\\1 #{language_name}\\n\"")
    end

    PLURAL_FORMS =
      /^(\"Plural-Forms:) nplurals=INTEGER; plural=EXPRESSION;\\n\"$/

    def replace_plural_forms(pot, locale)
      pot.gsub(PLURAL_FORMS, "\\1 #{plural_forms(locale)}\\n\"")
    end

    def plural_forms(locale)
      case locale.to_s
      when "ja", "vi", "ko"
        nplural = "1"
        plural_expression = "0"
      when "en", "de", "nl", "sv", "da", "no", "fo", "es", "pt",
           "it", "bg", "el", "fi", "et", "he", "eo", "hu", "tr"
        nplural = "2"
        plural_expression = "n != 1"
      when "pt_BR", "fr"
        nplural = "2"
        plural_expression = "n>1"
      when "lv"
        nplural = "3"
        plural_expression = "n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2"
      when "ga"
        nplural = "3"
        plural_expression = "n==1 ? 0 : n==2 ? 1 : 2"
      when "ro"
        nplural = "3"
        plural_expression = "n==1 ? 0 : " +
                              "(n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2"
      when "lt"
        nplural = "3"
        plural_expression = "n%10==1 && n%100!=11 ? 0 : " +
                              "n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2"
      when "ru", "uk", "sr", "hr"
        nplural = "3"
        plural_expression = "n%10==1 && n%100!=11 ? 0 : n%10>=2 && " +
                              "n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2"
      when "cs", "sk"
        nplural = "3"
        plural_expression = "(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2"
      when "pl"
        nplural = "3"
        plural_expression = "n==1 ? 0 : n%10>=2 && " +
                              "n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2"
      when "sl"
        nplural = "4"
        plural_expression = "n%100==1 ? 0 : n%100==2 ? 1 : n%100==3 " +
                              "|| n%100==4 ? 2 : 3"
      else
        nplural = nil
        plural_expression = nil
      end
      "nplurals=#{nplural}; plural=#{plural_expression};"
    end
  end
end

module GetText
  # Initialize a .pot file with user's environment and input and
  # create a .po file from an initialized .pot file.
  # A .pot file is specified as input_file. If input_file is not
  # specified, a .pot file existing current directory is used.
  # A .po file is created from initialized input_file as output_file.
  # if output_file isn't specified, output_file is "locale.po".
  # If locale is not specified, the current locale is used.
  def rmsginit
    GetText::RMsgInit.run(*ARGV)
    self
  end

  module_function :rmsginit
end

if $0 == __FILE__ then
  require 'pp'

  GetText.rmsginit
end
