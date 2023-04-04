#!/usr/bin/env ruby

require 'fileutils'
require 'pathname'
# rubygems
require 'nokogiri'
require 'sqlite3'

DOCSET_DIR_NAME = 'wezterm.docset'
TEMPLATE_DIR_NAME = 'template'
FONT_FAMILY_SANS = 'font-family: Verdana, sans-serif;'
FONT_FAMILY_MONO = 'font-family: Menlo, monospace;'
FONT_FAMILY_MISC = FONT_FAMILY_SANS
FONT_SIZE_FACTOR = 0.9

class Repository
  def initialize(home_dir)
    @home = home_dir
  end

  def home_dir
    @home
  end

  def each_file(&block)
    dirnames = %w[assets reference]

    dirnames.each(&block)
  end
end

class Docset
  def initialize(home_dir)
    @home = home_dir
  end

  def contents_dir
    File.join(@home, 'Contents')
  end

  def resources_dir
    File.join(contents_dir, 'Resources')
  end

  def documents_dir
    File.join(resources_dir, 'Documents')
  end

  def dsidx_path
    File.join(resources_dir, 'docSet.dsidx')
  end

  def each_document(extension, &block)
    basename = extension ? "*.#{extension}" : '*'
    Dir.glob(File.join(documents_dir, '**', basename), &block)
  end
end

class DocsetBuilder
  def initialize(env)
    @env = env
    @repos = Repository.new(env.repos_dir)
    @docset = Docset.new(env.docset_dir)
  end

  def build
    # copy_repos_files
    # copy_template_files
    # rewrite_files
    create_index
  end

  # def copy_repos_files
  #   FileUtils.mkdir_p(@docset.documents_dir) unless File.exist?(@docset.documents_dir)
  #
  #   @repos.each_file do |filename|
  #     src_path = File.join(@repos.home_dir, filename)
  #     dst_path = File.join(@docset.documents_dir, filename)
  #
  #     if File.exist?(dst_path)
  #       print('Cleaning docset directory...')
  #       FileUtils.rm_r(dst_path)
  #       puts('done.')
  #     end
  #
  #     print("Copying #{src_path}...")
  #     FileUtils.cp_r(src_path, dst_path)
  #     puts('done.')
  #   end
  # end

  # def copy_template_files
  #   print('Copying template files...')
  #
  #   # Copy additional CSS
  #   src_path = File.join(@env.template_dir, 'docset.css')
  #   dst_path = File.join(@docset.documents_dir, 'docset.css')
  #   FileUtils.cp(src_path, dst_path)
  #
  #   # Copy Info.plist
  #   src_path = File.join(@env.template_dir, 'Info.plist')
  #   dst_path = File.join(@docset.contents_dir, 'Info.plist')
  #   FileUtils.cp(src_path, dst_path)
  #
  #   puts('done.')
  # end

  # def rewrite_files
  #   @docset.each_document('html') do |path|
  #     rewrite_html(path)
  #   end
  #
  #   @docset.each_document('css') do |path|
  #     rewrite_css(path)
  #   end
  # end

  # def rewrite_html(path)
  #   print("Formatting #{File.dirname(path)}...")
  #
  #   lines = []
  #   File.open(path) do |f|
  #     while (line = f.gets)
  #       # Rewrite absolute paths
  #       line.gsub!(%r{/assets/}, '../../assets/')
  #       line.gsub!(%r{/reference/}, '../../reference/')
  #
  #       lines << line
  #     end
  #   end
  #
  #   # Insert additional CSS
  #   lines.each_index do |index|
  #     if lines[index].strip == '</head>'
  #       lines.insert(index, '<link rel="stylesheet" href="../../docset.css"/>')
  #       break
  #     end
  #   end
  #
  #   File.open(path, 'w') do |f|
  #     f.write(lines.join(''))
  #   end
  #
  #   puts('done.')
  # end
  #
  # def rewrite_css(path)
  #   print("Formatting #{File.dirname(path)}...")
  #
  #   lines = []
  #   File.open(path) do |f|
  #     while (line = f.gets)
  #       # Rewrite font family
  #       # Reference htmls use web fonts placed at http://assets.paperjs.org/,
  #       # but cannot access them by Cross-Origin policy.
  #       # So replace them with system default ones.
  #       line.gsub!(/font-family:.+sans-serif;/, FONT_FAMILY_SANS)
  #       line.gsub!(/font-family:.+monospace;/, FONT_FAMILY_MONO)
  #       line.gsub!(/font-family:.+";/, FONT_FAMILY_MISC)
  #
  #       # Rewrite font size
  #       # Default font size is largish for dash documentation
  #       # so make them smaller
  #       line.gsub!(/((?:font-size|line-height):\s*)([0-9.]+)/) do |_s|
  #         format('%s%.2f', ::Regexp.last_match(1), (::Regexp.last_match(2).to_f * FONT_SIZE_FACTOR))
  #       end
  #       line.gsub!(/(font-size:\s*)([0-9.]+)/) do |_s|
  #         format('%s%.2f', ::Regexp.last_match(1), (::Regexp.last_match(2).to_f * FONT_SIZE_FACTOR))
  #       end
  #
  #       lines << line
  #     end
  #   end
  #
  #   File.open(path, 'w') do |f|
  #     f.write(lines.join(''))
  #   end
  #
  #   puts('done.')
  # end

  def create_index
    print('Creating docset index...')

    path = @docset.dsidx_path
    FileUtils.rm(path) if File.exist?(path)

    DocsetIndex.new(path) do |dsi|
      dsi.create

      # Add method entries
      doc_pathname = Pathname.new(@docset.documents_dir)
      @docset.each_document('html') do |html_path|
        html_pathname = Pathname.new(html_path)
        rel_path = html_pathname.relative_path_from(doc_pathname).to_s

        DocumentParser.parse(html_path) do |name, type, hash|
          entry_path = rel_path + (hash.empty? ? '' : "##{hash}")
          dsi.add(name, type, entry_path)

          puts("Added docset index: #{name}, #{type}, #{entry_path}")
        end
      end
    end

    puts('done.')
  end
end

class DocumentParser
  SPECIAL_TYPES = {
    'Global Scope' => 'Global'
  }

  def self.parse(path)
    html = nil
    File.open(path) do |f|
      html = f.read
    end

    doc = Nokogiri::HTML.parse(html, nil)

    # Class
    name = doc.css('h1').text
    type = SPECIAL_TYPES.fetch(name, 'Class')
    yield name, type, ''

    # Methods
    doc.css('.member').each do |node|
      name = node.css('.member-link').text.strip
      hash = node.attribute('id').to_s

      yield name, 'Method', hash
    end
  end
end

class DocsetIndex
  def initialize(path)
    SQLite3::Database.open(path) do |db|
      @db = db
      yield self
    end
    @db = nil
  end

  def create
    sql = <<-SQL
      CREATE TABLE searchIndex(
        id INTEGER PRIMARY KEY,
        name TEXT,
        type TEXT,
        path TEXT
      );
    SQL
    @db.execute(sql)
  end

  def add(name, type, path)
    sql = <<-SQL
      INSERT OR IGNORE INTO
        searchIndex(name, type, path)
        VALUES(?, ?, ?)
    SQL
    @db.execute(sql, name, type, path)
  end
end

class Environment
  attr_accessor :repos_dir, :docset_dir # , :template_dir
end

if __FILE__ == $0
  script_home = __dir__

  env = Environment.new
  # env.repos_dir = File.join(script_home, REPOS_NAME)
  env.repos_dir = File.join(script_home, 'build', 'artifact')
  env.docset_dir = File.join(script_home, DOCSET_DIR_NAME)
  # env.template_dir = File.join(script_home, TEMPLATE_DIR_NAME)

  builder = DocsetBuilder.new(env)
  builder.build
end
