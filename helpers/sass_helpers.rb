# coding: utf-8
require "pathname"
require "redcarpet"
require "rouge"
require "rouge/plugins/redcarpet"

module SassHelpers
  def page_title
    title = "Sass: "
    if current_page.data.title
      title << current_page.data.title
    else
      title << "Syntactically Awesome Style Sheets"
    end
    title
  end

  def copyright_years(start_year)
    end_year = Date.today.year
    if start_year == end_year
      start_year.to_s
    else
      start_year.to_s + '&ndash;' + end_year.to_s
    end
  end

  def pages_for_group(group_name)
    group = data.nav.find do |g|
      g.name == group_name
    end

    pages = []

    return pages unless group

    if group.directory
      pages << sitemap.resources.select { |r|
        r.path.match(%r{^#{group.directory}}) && !r.data.hidden
      }.map do |r|
        ::Middleman::Util.recursively_enhance({
          :title => r.data.title,
          :path  => r.url
        })
      end.sort_by { |p| p.title }
    end

    pages << group.pages if group.pages

    pages.flatten
  end

  # Renders a code example.
  #
  # This takes a block of SCSS and/or indented syntax code, and emits HTML that
  # (combined with JS) will allow users to choose which to display.
  #
  # The SCSS should be separated from the Sass with `===`. For example, in Haml:
  #
  #     - example do
  #       :plain
  #         .foo {
  #           color: blue;
  #         }
  #         ===
  #         .foo
  #           color: blue
  #
  # Different sections can be separated within one syntax (for example, to
  # indicate different files) with `---`. For example, in Haml:
  #
  #     - example do
  #       :plain
  #         // _reset.scss
  #         * {margin: 0}
  #         ---
  #         // base.scss
  #         @import 'reset';
  #         ===
  #         // _reset.sass
  #         *
  #           margin: 0;
  #         ---
  #         // base.sass
  #         @import reset
  #
  # Padding is added to the bottom of each section to make it the same length as
  # the section in the other language.
  #
  # A third section may optionally be provided to represent compiled CSS. If
  # it's not passed and `autogen_css` is `true`, it's generated from the SCSS
  # source. If the autogenerated CSS is empty, it's omitted entirely.
  #
  # If `syntax` is either `:sass` or `:scss`, the first section will be
  # interpreted as that syntax and the second will be interpreted (or
  # auto-generated) as the CSS output.
  def example(autogen_css: true, syntax: nil, &block)
    contents = _capture(&block)

    if syntax == :scss
      scss, css = contents.split("\n===\n")
    elsif syntax == :sass
      sass, css = contents.split("\n===\n")
    else
      scss, sass, css = contents.split("\n===\n")
      throw ArgumentError.new("Couldn't find === in:\n#{contents}") if sass.nil?
    end

    scss_sections = scss ? scss.split("\n---\n").map(&:strip) : []
    sass_sections = sass ? sass.split("\n---\n").map(&:strip) : []

    if css.nil? && autogen_css
      sections = scss ? scss_sections : sass_sections
      if sections.length != 1
        throw ArgumentError.new(
                "Can't auto-generate CSS from more than one SCSS file.")
      end

      css = Sass::Engine.new(
        sections.first,
        syntax: syntax || :scss,
        style: :expanded
      ).render
      css = nil if css.empty?
    end
    css_sections = css ? css.split("\n---\n").map(&:strip) : []

    # Calculate the lines of padding to add to the bottom of each section so
    # that it lines up with the same section in the other syntax.
    scss_paddings = []
    sass_paddings = []
    css_paddings = []
    max_num_sections =
      [scss_sections, sass_sections, css_sections].map(&:length).max
    max_num_sections.times do |i|
      scss_section = scss_sections[i]
      sass_section = sass_sections[i]
      css_section = css_sections[i]
      scss_lines = (scss_section || "").lines.count
      sass_lines = (sass_section || "").lines.count
      css_lines = (css_section || "").lines.count

      # Whether the current section is the last section for the given syntax.
      last_scss_section = i == scss_sections.length - 1
      last_sass_section = i == sass_sections.length - 1
      last_css_section = i == css_sections.length - 1

      # The maximum lines for any syntax in this section, ignoring syntaxes for
      # which this is the last section.
      max_lines = [
        last_scss_section ? 0 : scss_lines,
        last_sass_section ? 0 : sass_lines,
        last_css_section ? 0 : css_lines
      ].max

      scss_paddings <<
        if last_scss_section
          # Make sure the last section has as much padding as all the rest of
          # the other syntaxes' sections.
          _total_padding(sass_sections[i..-1], css_sections[i..-1]) -
            scss_lines - 2
        elsif max_lines > scss_lines
          max_lines - scss_lines
        end

      sass_paddings <<
        if last_sass_section
          _total_padding(scss_sections[i..-1], css_sections[i..-1]) -
            sass_lines - 2
        elsif max_lines > sass_lines
          max_lines - sass_lines
        end

      css_paddings <<
        if last_css_section
          _total_padding(scss_sections[i..-1], sass_sections[i..-1]) -
            css_lines - 2
        elsif max_lines > css_lines
          max_lines - css_lines
        end
    end

    @unique_id ||= 0
    @unique_id += 1
    id = @unique_id
    contents = []
    if scss
      contents <<
        _syntax_div("SCSS Syntax", "scss", scss_sections, scss_paddings, id)
    end

    if sass
      contents <<
        _syntax_div("Sass Syntax", "sass", sass_sections, sass_paddings, id)
    end

    if css
      contents <<
        _syntax_div("CSS Output", "css", css_sections, css_paddings, id)
    end

    text = content_tag(:div, contents,
      class: "code-example",
      "data-unique-id": @unique_id)

    # Newlines between tags cause Markdown to parse these blocks incorrectly.
    text = text.gsub(%r{\n+<(/?[a-z0-9]+)}, '<\1')
    if block_is_haml?(block)
      haml_concat text
    else
      # Padrino's concat helper doesn't play nice with nested captures.
      @_out_buf << text
    end
  end

  # Returns the number of lines of padding that's needed to match the height of
  # the `<pre>`s generated for `sections1` and `sections2`.
  def _total_padding(sections1, sections2)
    sections1 ||= []
    sections2 ||= []
    [sections1, sections1].map(&:length).max.times.sum do |i|
      # Add 2 lines to each additional section: 1 for the extra padding, and 1
      # for the extra margin.
      [
        (sections1[i] || "").lines.count,
        (sections2[i] || "").lines.count
      ].max + 2
    end
  end

  # Returns the text of an example div for a single syntax.
  def _syntax_div(name, syntax, sections, paddings, id)
    content_tag(:div, [
      content_tag(:h3, name),
      *sections.zip(paddings).map do |section, padding|
        padding = 0 if padding.nil? || padding.negative?
        _render_markdown("```#{syntax}\n#{section}#{"\n" * padding}\n```")
      end
    ], id: "example-#{id}-#{syntax}", class: syntax)
  end

  # Returns the version for the given implementation (`:dart`, `:ruby`, or
  # `:libsass`), or `nil` if it hasn't been made available yet.
  def impl_version(impl)
    data.version && data.version[impl]
  end

  # Returns the URL tag for the latest release of the given implementation.
  def release_url(impl)
    version = impl_version(impl)
    repo =
      case impl
      when :dart; "dart-sass"
      when :libsass; "libsass"
      when :ruby; "sass"
      end

    if version
      "https://github.com/sass/#{repo}/releases/tag/#{version}"
    else
      "https://github.com/sass/#{repo}/releases"
    end
  end

  # Returns HTML for a warning.
  #
  # The contents should be supplied as a block.
  def heads_up
    concat(content_tag :aside, [
      content_tag(:h3, 'Heads up!'),
      _render_markdown(_capture {yield})
    ], class: 'sl-c-callout sl-c-callout--warning')
  end

  # Returns HTML for a fun fact that's not directly relevant to the main
  # documentation.
  #
  # The contents should be supplied as a block.
  def fun_fact
    concat(content_tag :aside, [
      content_tag(:h3, 'Fun fact:'),
      _render_markdown(_capture {yield})
    ], class: 'sl-c-callout sl-c-callout--fun-fact')
  end

  def table_of_contents(resource)
    content = File.read(resource.source_file)
    toc_renderer = Redcarpet::Render::HTML_TOC.new
    markdown = Redcarpet::Markdown.new(toc_renderer)
    markdown.render(content)
  end

  def markdown_wrap(content)
    Tilt['markdown'].new { content }.render
  end

  # Renders a status dashboard for each implementation's support for a feature.
  #
  # Each implementation's value can be `true`, indicating that that
  # implementation fully supports the feature; `false`, indicating that it does
  # not yet support the feature; or a string, indicating the version it started
  # supporting the feature.
  #
  # When possible, prefer using the start version rather than `true`.
  #
  # This takes a Markdown block that should provide more information about the
  # implementation differences or the old behavior.
  def impl_status(dart: nil, libsass: nil, ruby: nil, node: nil)
    contents = []
    contents << _impl_status_row('Dart Sass', dart) if dart
    contents << _impl_status_row('LibSass', libsass) if libsass
    contents << _impl_status_row('Node Sass', node) if node
    contents << _impl_status_row('Ruby Sass', ruby) if ruby

    if block_given?
      contents.unshift(content_tag(:caption, [
        _render_markdown(_capture {yield})
      ]))
    end

    concat(content_tag :table, contents, class: 'impl-status')
  end

  # Renders a single row for `impl_status`.
  def _impl_status_row(name, status)
    status_text =
      if status == true
        "✓"
      elsif status == false
        "✗"
      else
        "since #{status}"
      end

    content_tag :tr, [
      content_tag(:th, name, class: 'name'),
      content_tag(:th, status_text, class: 'status'),
    ], class: status ? 'supported' : 'unsupported'
  end

  # Renders API docs for a Sass function.
  #
  # The function's name is parsed from the signature. The API description is
  # passed as a Markdown block. If `returns` is passed, it's included as the
  # function's return type.
  #
  # Multiple signatures may be passed, in which case they're all included in
  # sequence.
  def function(*signatures, returns: nil)
    names = []
    highlighted_signatures = signatures.map do |signature|
      name = signature.split("(").first
      names << name
      html = Nokogiri::HTML(_render_markdown(<<MARKDOWN))
```scss
@function #{signature}
{}
```
MARKDOWN
      highlighted_signature = html.css("pre code").children.
        drop_while {|el| el.text != "@function"}.
        take_while {|el| el.text != "{}"}[1...-1].
        map(&:to_html).join.strip
    end

    html = content_tag :div, [
      content_tag(:pre, [
        content_tag(:code, highlighted_signatures.join("\n"))
      ], class: 'signature highlight scss'),
      returns ? content_tag(:div, return_type_link(returns), class: 'return-type') : '',
      _render_markdown(_capture {yield})
    ], class: 'function', id: names.first

    concat(names.uniq[1..-1].inject(html) {|h, n| content_tag(:div, h, id: n)})
  end

  def return_type_link(return_type)
    return_type.split("|").map do |type|
      type = type.strip
      case type.strip
      when 'number'; link_to type, '/documentation/values/numbers'
      when 'string'; link_to type, '/documentation/values/strings'
      when 'quoted string'; link_to type, '/documentation/values/strings#quoted'
      when 'unquoted string'; link_to type, '/documentation/values/strings#unquoted'
      when 'color'; link_to type, '/documentation/values/colors'
      when 'list'; link_to type, '/documentation/values/lists'
      when 'map'; link_to type, '/documentation/values/maps'
      when 'boolean'; link_to type, '/documentation/values/booleans'
      when 'null'; link_to '<code>null</code>', '/documentation/values/null'
      when 'function'; link_to type, '/documentation/values/functions'
      when 'selector'; link_to type, '/documentation/functions/selector#selector-values'
      else raise "Unknown type #{type}"
      end
    end.join(" | ")
  end

  # Removes leading spaces from every non-empty line in `text` while preserving
  # relative indentation.
  def remove_leading_indentation(text)
    text.gsub(/^#{text.scan(/^ *(?=\S)(?!<)/).min}/, "")
  end

  # A helper method that renders a chunk of Markdown text.
  def _render_markdown(content)
    @redcarpet ||= Redcarpet::Markdown.new(
      Class.new(Redcarpet::Render::HTML) { include Rouge::Plugins::Redcarpet },
      markdown
    )
    find_and_preserve(@redcarpet.render(content))
  end

  # Captures the contents of `block` from ERB or Haml.
  #
  # Strips all leading indentation from the block.
  def _capture(&block)
    remove_leading_indentation(
      block_is_haml?(block) ? capture_haml(&block) : capture(&block))
  end
end
