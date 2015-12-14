#!/bin/bash
set -e

# Generates tracker code for positive emotion
function positive_tracker_emoticon() {
    local rand=$[ RANDOM % 5]
    # Only do fun stuff 1/6 of the time:
    if [[ $rand -eq 0 ]]
    then
        image=$(get_happy_image)
        echo "!${image}!"
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
        echo "!${image}!"
    else
        echo  '(n)'
    fi
}


function get_happy_image() {
    # Christmas time..
    images[0]='https://twemoji.maxcdn.com/16x16/1f384.png'
    images[1]='https://twemoji.maxcdn.com/16x16/1f385.png'

    index=$[$RANDOM % ${#images[@]}]
    echo ${images[$index]}
}

function get_sad_image() {
    # fire 🔥
    images[0]='https://twemoji.maxcdn.com/16x16/1f525.png'
    # pile of poo 💩
    images[1]='https://twemoji.maxcdn.com/16x16/1f4a9.png'
    # speak-no-evil monkey 🙊
    images[2]='https://twemoji.maxcdn.com/16x16/1f64a.png'
    # bug 🐜
    images[3]='https://twemoji.maxcdn.com/16x16/1f41c.png'
    # face screaming in fear 😱
    images[4]='https://twemoji.maxcdn.com/16x16/1f631.png'
    # construction sign 🚧
    images[5]='https://twemoji.maxcdn.com/16x16/1f6a7.png'
    # sos 🆘
    images[6]='https://twemoji.maxcdn.com/16x16/1f198.png'
    # skull 💀
    images[7]='https://twemoji.maxcdn.com/16x16/1f480.png'

    index=$[$RANDOM % ${#images[@]}]
    echo ${images[$index]}
}
