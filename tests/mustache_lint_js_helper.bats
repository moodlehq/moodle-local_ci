#!/usr/bin/env bats

load libs/bats-support/load
load libs/bats-assert/load

setup () {
    moodleroot="$BATS_TEST_TMPDIR/moodle"
    mkdir -p "$moodleroot/node_modules/.bin" "$moodleroot/public"
    touch "$moodleroot/package.json" "$moodleroot/.eslintrc"

    # Check the executable, configuration and working directory used by the helper.
    cat > "$moodleroot/node_modules/.bin/eslint" <<'EOF'
#!/usr/bin/env bash
[[ "$PWD" == "$(dirname "$(dirname "$(dirname "$0")")")" ]] || exit 1
[[ "$*" == "--stdin --no-eslintrc --config $PWD/.eslintrc --format=json" ]] || exit 1
[[ "$(cat)" == "var example = true;" ]] || exit 1
printf '%s\n' '[{"messages":[{"message":"ESLint ran","line":1}]}]'
EOF
    chmod +x "$moodleroot/node_modules/.bin/eslint"
}

check_eslint () {
    run php -r '
        require $argv[1] . "/vendor/autoload.php";
        require $argv[1] . "/mustache_lint/js_helper.php";
        $helper = new js_helper($argv[2]);
        $engine = new Mustache_Engine(["helpers" => ["js" => function($content, \Mustache_LambdaHelper $lambdahelper) use ($helper) {
            $helper->add_js($content, $lambdahelper);
        }]]);
        $engine->render("{{#js}}var example = true;{{/js}}");
        $messages = $helper->run_eslint();
        echo $messages[0]->message ?? "ESLint did not run";
    ' "$BATS_TEST_DIRNAME/.." "$1"

    assert_success
    assert_output "ESLint ran"
}

@test "mustache_lint: ESLint uses the root of a flat Moodle layout" {
    # A parent project must not override Moodle's own package.json.
    touch "$BATS_TEST_TMPDIR/package.json"
    check_eslint "$moodleroot"
}

@test "mustache_lint: ESLint uses the project root above Moodle's public directory" {
    check_eslint "$moodleroot/public"
}
