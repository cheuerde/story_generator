# install openai package from github
# install.packages("devtools")
# devtools::install_github("ropensci/openai")

library(pacman)
p_load(openai, tidyverse, shiny, jsonlite, lubridate, base64, logger, markdown, png)

# install the ubuntu dependencies for the loaded packages
# system("sudo apt-get install libcurl4-openssl-dev libssl-dev texlive-full"

# we also need libxml2-dev
# system("sudo apt-get install libxml2-dev")

get_story <- function(
    OPENAI_API_KEY = Sys.getenv("OPENAI_API_KEY"),
                      chapters = 3,
                      words_per_chapter = 50,
                      date = lubridate::today(),
                      topic = "bears in the wood, eating honey",
                      prompt = NULL,
                      progress = NULL,
                      model_in = c(
                        "text-davinci-003",
                        "text-curie-001",
                        "text-babbage-001",
                        "text-ada-001",
                        "code-davinci-002",
                        "code-cushman-001"
                      )
                      ) {
    # get your API key from https://beta.openai.com/account/api-keys
    Sys.setenv(OPENAI_API_KEY = OPENAI_API_KEY)

    min_chapters = chapters - 1
    max_chapters = chapters + 1

    min_words_per_chapter = words_per_chapter - 30
    max_words_per_chapter = words_per_chapter + 30

    if (is.null(prompt)) {
        prompt <- paste(
            '
Write a story with between ', min_chapters, ' and ', max_chapters, 
' chapters and between ', min_words_per_chapter, ' and ', max_words_per_chapter, 
' words for each chapter.
The user inputs some keywords or sentences as to what the story is supposed to be about.
You shall then detect the user input language.
Then generate the story (in English, with very deteailed description of events) and translate that story to the user input language.
Also define a title for the story and for each chapter and the title page generate some
keywords (always use nouns and adjectives) for a diffusion model to generate an image that
fits to the given chapter (no more than 10 keywords). For the backcover, generate a brief
summary of the story.
The output shall be a json file with the following structure:
{
    "title": "The title of the story",
    "author": "The author of the story",
    "date": "The date of the story",
    "user_input_language": "The language of the story",
    "image_prompt_title_page": "The image prompt for the title page of the story",
    "summary_backcover": "The summary of the story",
    "chapters": [
        {
            "chapter_number": 1,
            "text": "The text of the first chapter",
            "image_prompt": "The image prompt for the diffusion model for the first chapter"
        },
        {
            "chapter_number": 2,
            "text": "The text of the second chapter"
            "image_prompt": "The image prompt for the diffusion model for the second chapter"
        }
        {
            ...
        }
    ]
}

The image prompts shall be in English. The title, backcover summary and chapter texts
shall be in the user input language.
Output only the json file, nothing else (start with "{"). Only use UTF-8 characters.
Escape any single or double quotes in the text with a backslash.
This is the topic of the story as input by the user:
', topic,
            sep = ""
        )
    }

message = "Querying OpenAI for story generation"
log_info(message)
if(!is.null(progress)) progress$message = message

    # create a new completion with davinci_003:0
    txt <- openai::create_completion(
        model = model_in,
        prompt = prompt,
        suffix = NULL,
        max_tokens = 3000,
        temperature = 0.7,
        top_p = 1,
        n = 1,
        stream = FALSE,
        logprobs = NULL,
        echo = FALSE,
        stop = NULL,
        presence_penalty = 0,
        frequency_penalty = 0,
        best_of = 1,
        logit_bias = NULL,
        user = NULL,
        openai_api_key = Sys.getenv("OPENAI_API_KEY"),
        openai_organization = NULL
    )

    # first, read the json and put it into a tibble
    txt_string = txt$choices$text
    # sometimes we have leading random characters in the response before
    # the json start, remove here
    txt_string = gsub("^[^\\{]*\\{", "{", txt_string)
    dat <- jsonlite::fromJSON(txt_string)
    dat$prompt <- prompt

    return(dat)
}

# compile the story to pdf or markdown
compile_story <- function(
                          dat,
                          image_pre_prompt = "
    Breath-taking digital painting with warm colours amazing art mesmerizing,
    captivating, artstation 3
    ",
                          create_images = TRUE,
                          create_pdf = FALSE,
                          folder = tempdir(),
                          progress = NULL,
                          image_size = "1024x1024"
                          ) {

    if (create_images) {

message = "creating images for story"
log_info(message)
if(!is.null(progress)) progress$message = message

message = "creating image for title page"
log_info(message)
if(!is.null(progress)) progress$message = message

        # create image for title page
        img <- create_image(
            prompt = paste(dat$image_prompt_title_page, image_pre_prompt, sep = ", "),
            n = 1,
            size = "1024x1024",
            # size = c("1024x1024", "256x256", "512x512"),
            response_format = c("b64_json"),
            user = NULL,
            openai_api_key = Sys.getenv("OPENAI_API_KEY"),
            openai_organization = NULL
        )

        raw_image <- base64_dec(img$data$b64_json[1])
        writeBin(raw_image, paste(folder, "/title_page.png", sep = ""))

        # loop over chapters and create images using openai::create_image
        for (i in 1:nrow(dat$chapters)) {

message = paste("chapter image", i, sep = " ")
log_info(message)
if(!is.null(progress)) progress$message = message

            # create an image with the dalle engine
            img <- create_image(
                prompt = paste(dat$chapters$image_prompt[i], image_pre_prompt, sep = ", "),
                n = 1,
                size = "256x256",
                response_format = c("b64_json"),
                user = NULL,
                openai_api_key = Sys.getenv("OPENAI_API_KEY"),
                openai_organization = NULL
            )

            raw_image <- base64_dec(img$data$b64_json[1])
            writeBin(raw_image, paste(folder, "/image_", i, ".png", sep = ""))
        }

    } else {

        empty_png <- array(0, dim = c(1,1,4))
        png::writePNG(empty_png, paste(folder, "/title_page.png", sep = ""))

        for (i in 1:nrow(dat$chapters)) {

            png::writePNG(empty_png, paste(folder, "/image_", i, ".png", sep = ""))

        }

    }

###############################
### put everything together ###
###############################

message = "makging markdown file"
log_info(message)
if(!is.null(progress)) progress$message = message

# markdown
  markdown_text <- 
  paste0("
|  | |
|----------|----------|
|-- Summary --||
|     ", dat$author, " | ", dat$title, " |
|     ", dat$date, " |  |
| | |
|     ", dat$summary_backcover, " | ![Image caption](", paste(folder, "/title_page.png", sep = ''), ") |
|-- Chapters --||"
  )

  for(i in 1:nrow(dat$chapters)) {

    markdown_text <- paste0(
        markdown_text, "
|", dat$chapters$text[i], " | ![](", paste(folder, "/image_", i, ".png", sep = ''), ") |"
    )

    }

    # Latex
    #
    # write every chapter into an infividual tex file
    # then compile the tex file into a pdf
    # the tex template that will include all the individual tex files

message = "makging latex file"
log_info(message)
if(!is.null(progress)) progress$message = message

    tex_start <-
        "
\\documentclass[a4paper,landscape]{article}
\\usepackage[top=2cm, bottom=2cm, left=2cm, right=2cm]{geometry}
\\usepackage{graphicx}
\\usepackage{setspace} % for line spacing
\\onehalfspacing % set line spacing to 1.5

\\begin{document}
"

    tex_end <-
        "
\\end{document}
"

    tex <- tex_start

    # add the title page
    tex <- paste(
        tex,
        "
    \\begin{minipage}[h]{0.4\\textwidth}
    \\centering
    \\Large
    ", dat$author, "

    \\vspace{0.5cm}

    ", as_date(dat$date), "

    \\vspace{2.5cm}

    %Prompt has been:

    \\Large
    %\\begin{verbatim}

    ", dat$summary_backcover, "

    %\\end{verbatim}

    \\end{minipage}%
    \\hspace{0.2\\linewidth}
    \\begin{minipage}[h]{0.4\\textwidth}
    \\centering
    \\Huge

    ", dat$title, "

    \\vspace{0.5cm}

    \\includegraphics[width=\\textwidth]{title_page.png}
    \\end{minipage}
    ",
        sep = ""
    )

    # add individual chapters
    for (i in 1:nrow(dat$chapters)) {
        cat(
            dat$chapters$text[i],
            file = paste(
                folder,
                "/chapter_",
                dat$chapters$chapter_number[i],
                ".tex",
                sep = ""
            )
        )

        # add the chapter to the tex file
        tex <- paste(
            tex,
            "
                \\begin{minipage}[h]{0.4\\linewidth}
                \\centering
                \\Large
                ",
            "\\input{chapter_", dat$chapters$chapter_number[i], ".tex}
                \\end{minipage}%
                \\hspace{0.2\\linewidth}
                \\begin{minipage}[h]{0.4\\textwidth}
                \\centering
                \\includegraphics[width=\\textwidth]{image_",
            dat$chapters$chapter_number[i],
            ".png}
                \\end{minipage}
                ",
            sep = ""
        )
    }

    # add end of tex file
    tex <- paste(tex, tex_end, sep = "")

    # create pdf from tex using pdflatex
    cat(
        tex,
        file = paste(folder, "/story.tex", sep = "")
    )

    if(create_pdf) {

message = "creating pdf"
log_info(message)
if(!is.null(progress)) progress$message = message

    system(
        paste(
            "pdflatex -output-directory=",
            folder,
            " ",
            folder,
            "/story.tex",
            sep = ""
        )
    )

    }

    return(
        list(
            tex = tex,
            markdown = markdown_text,
            pdf = paste(folder, "/story.pdf", sep = ""),
            images = list(
                title_page = paste(folder, "/title_page.png", sep = ""),
                cahpter_images = paste(folder, "/image_", 1:nrow(dat$chapters), ".png", sep = "")
            )
        )
    )

}


#######################
### Recipe function ###
#######################

# a similar function that will get a recipe from the openai api
get_recipe <- function(OPENAI_API_KEY = Sys.getenv("OAI_API_KEY"),
                       complexity = 1:10,
                       topic = "Rouladen mal anders",
                       prompt = NULL,
                       uom = "metric") {
    # get your API key from https://beta.openai.com/account/api-keys
    Sys.setenv(OPENAI_API_KEY = OPENAI_API_KEY)

    if (is.null(prompt)) {
        prompt <- paste(
            "
Write a recipe for a dish.
The user inputs some keywords or sentences as to what the recipe is supposed to be about.
the user inputs a number
Assume the complexity of preparing a dish can be between 1 and 10, with 1 being the easiest
and 10 being the most difficult,
for this dish the complexity shall be ", complexity, ".
Please detect the user input language.
Then generate the recipe (in English) and translate that recipe to the user input language.
Use the ", uom, ' system for the units of measurement.
Give a rough estimate of the total preparation time for the dish.
Also define a title for the recipe and generate some keywords (always use nouns and adjectives)
for a diffusion model to generate an image that fits to the given recipe (no more than 10 keywords).
The output shall be a json file with the following structure:

{
    "title": "The title of the recipe",
    "author": "The author of the recipe",
    "date": "The date of the recipe",
    "user_input_language": "The language of the recipe",
    "image_prompt": "The image prompt for the diffusion model for the recipe",
    "total_preparation_time": "Time in hours that it takes to prepare the dish",
    "ingredients": [
        {
            "ingredient_number": 1,
            "text": "The text of the first ingredient"
        },
        {
            "ingredient_number": 2,
            "text": "The text of the second ingredient"
        }
        {
            ...
        }
    ],
    "steps": [
        {
            "step_number": 1,
            "text": "The text of the first step"
        },
        {
            "step_number": 2,
            "text": "The text of the second step"
        }
        {
            ...
        }
    ]
}

The image prompt shall be in English, the title and ingredient and step texts in the
user input language.
Output only the json file, nothing else. start with "{", which marks the beginning
of the json file.
Escape any single or double quotes in the text with a backslash.
This is the input for the recipe from the user:
', topic,
            sep = ""
        )
    }

    # create a new completion with davinci_003:0
    txt <- openai::create_completion(
        model = "text-davinci-003",
        prompt = prompt,
        suffix = NULL,
        max_tokens = 2000,
        temperature = 0.7,
        top_p = 1,
        n = 1,
        stream = FALSE,
        logprobs = NULL,
        echo = FALSE,
        stop = NULL,
        presence_penalty = 0,
        frequency_penalty = 0,
        best_of = 1,
        logit_bias = NULL,
        user = NULL,
        openai_api_key = Sys.getenv("OPENAI_API_KEY"),
        openai_organization = NULL
    )

    # first, read the json and put it into a tibble
    # dat <- jsonlite::fromJSON(txt$choices$text)
    # dat$prompt <- prompt

    return(txt)
}
