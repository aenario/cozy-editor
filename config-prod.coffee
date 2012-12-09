exports.config =
    # See docs at http://brunch.readthedocs.org/en/latest/config.html.
    coffeelint:
        pattern: /^app\/.*\.coffee$/
        options:
            indentation:
                value: 4
                level: "ignore"
            max_line_length:
                value: 80
                level: "ignore"
            no_trailing_whitespace:
                level: "ignore"
            no_trailing_semicolons:
                level: "ignore"
            no_backticks:
                level: "ignore"

    files:
        javascripts:
            joinTo:
                'bin/CNeditor.js': /^app\/views\/CNeditor/
                'javascripts/tests.js': /^test/

        stylesheets:
            joinTo:
                'bin/CNeditor.css': /^app\/views\/CNeditor/

    modules:
        wrapper: false
        definition:  (path, data) ->
            if path=="public/bin/CNeditor.js"
                data = data.replace(/exports\.CNeditor/, "CNeditor")
                return data

    # minify: true
    # optimize: true
    # none of those syntax work, there is a pb in the documentation : 
    # http://brunch.readthedocs.org/en/latest/config.html#optimize
