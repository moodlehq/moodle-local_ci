#!/usr/bin/env bash
set -e

# Generates tracker code for positive emotion
function positive_tracker_emoticon() {
    local rand=$[ RANDOM % 2]
    # Only do fun stuff 1/3 of the time:
    if [[ $rand -eq 0 ]]
    then
        image=$(get_happy_image)
        echo "${image}"
    else
        echo  '(y)'
    fi
}

# Generates tracker comment code for negative emotion
function negative_tracker_emoticon() {
    local rand=$[ RANDOM % 5]
    # Only do fun stuff 1/6 of the time:
    if [[ $rand -eq 0 ]]
    then
        image=$(get_sad_image)
        echo "${image}"
    else
        echo  '(n)'
    fi
}


function get_happy_image() {
    # smiling face with halo 😇
    images[0]='😇'
    # balloon🎈
    images[1]='🎈'
    # party popper 🎉
    images[2]='🎉'
    # clinking beer mugs 🍻
    images[3]='🍻'
    # cookie 🍪
    images[4]='🍪'
    # cake 🍰
    images[5]='🍰'
    # glowing star 🌟
    images[6]='🌟'

    index=$[$RANDOM % ${#images[@]}]
    echo ${images[$index]}
}

function get_sad_image() {
    # fire 🔥
    images[0]='🔥'
    # pile of poo 💩
    images[1]='💩'
    # speak-no-evil monkey 🙊
    images[2]='🙊'
    # bug 🐜
    images[3]='🐜'
    # face screaming in fear 😱
    images[4]='😱'
    # construction sign 🚧
    images[5]='🚧'
    # sos 🆘
    images[6]='🆘'
    # skull 💀
    images[7]='💀'

    index=$[$RANDOM % ${#images[@]}]
    echo ${images[$index]}
}
