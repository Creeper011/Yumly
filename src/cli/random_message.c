#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#ifdef _WIN32
    #include <process.h>
    #define getpid _getpid
#else
    #include <unistd.h>
#endif

static const char* messages[] = {
    "leave me alone!! >_<",
    "here you go, my lord! ♡",
    "hold on, i'm gaming!!",
    "heyyy!! (ㆆ_ㆆ)",
    "am i cute? i'm trying my very best... ♡",
    "good girl :3",
    "good boy :3",
    "good shiny girl ✨",
    "ah yoooo!!",
    "there!! happy now? >:3",
    "all yours, my dear ♡",
    "done!! praise me now (˶>⩊<˶)",
    "you're welcomeee :3",
    "see? i'm amazing ✨",
    "tadaaa!! ♡",
    "hmph... there you have it!",
    "don't stare at me like that!! >_<",
    "hey!! be nice to me (ㆆ_ㆆ)",
    "what are you looking at? >:3",
    "i did it!! i did it!!",
    "hehe... easy :3",
    "did you miss me? ♡",
    "say thank you to Yummie!!",
    "you owe me a headpat now >:3",
    "one headpat, please... ;-;",
    "look!! no explosions this time!!",
    "nothing broke!! yaaay!!",
    "behold... your precious config ✨",
    "a gift for you! ⸜(｡˃ ᵕ ˂ )⸝♡",
    "i hope you like it... 🥀",
    "am i useful? say yes!!",
    "i'm not blushing, okay? >_<",
    "that was kinda fun, actually :3",
    "yippee!!",
    "wa wa wa ♡",
    "nya hello!!",
    "okay bye!! ...unless?",
    "come back soon, okay? ♡",
    "bye bye and see you later ♡"
};

static int seeded = 0;

const char* random_message(void) {
    if (!seeded) {
        srand((unsigned int)(time(NULL) ^ getpid()));
        seeded = 1;
    }

    int num_messages = sizeof(messages) / sizeof(messages[0]);
    return messages[rand() % num_messages];
}
