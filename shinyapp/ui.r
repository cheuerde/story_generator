ui <- fluidPage(
    fluidRow(
        column(
            width = 4,
            wellPanel(

                #checkboxInput(
                #    inputId = "create_pdf",
                #    label = "create pdf",
                #    value = TRUE
                #),

                # text input for the image_pre_prompt
                textAreaInput(
                    inputId = "image_pre_prompt",
                    label = "image pre prompt",
                    value = 
                    "Breath-taking digital painting with warm colours amazing art mesmerizing, captivating, artstation 3",
                    width = "200px",
                    height = "100px"
                ),

                # dropdown selector for the model to use for completion
                selectInput(
                    inputId = "model",
                    label = "model",
                    #choices = c(
                    #    "text-davinci-003",
                    #    "text-curie-001",
                    #    "text-babbage-001",
                    #    "text-ada-001",
                    #    "code-davinci-002",
                    #    "code-cushman-001"
                    #),
                    choices = c("text-davinci-003"),
                    selected = "text-davinci-003"
                ),


                # the input for the topic should be a muliline box
                textAreaInput(
                    inputId = "topic",
                    label = "topic",
                    value = "two detective girls capturing an evil fox that kindnapped the prince",
                    width = "200px",
                    height = "100px"
                ),

                    # user inpute for chapters
                    numericInput(
                        inputId = "chapters",
                        label = "number of chapters",
                        value = 4,
                        min = 1,
                        max = 10
                    ),
                    # and words per chapter
                    numericInput(
                        inputId = "words_per_chapter",
                        label = "words per chapter",
                        value = 100,
                        min = 1,
                        max = 1000
                    ),

                checkboxInput(
                    inputId = "create_images",
                    label = "create images",
                    value = FALSE
                ),
                    # we need a "generate story" button
                    actionButton(
                        inputId = "generate_story",
                        label = "generate story"
                    ),
                    # and a download button for the pdf from the server
                    downloadButton(
                        outputId = "download_pdf",
                        label = "download pdf"
                    ),
                    # output the messages from progress
                    verbatimTextOutput("progress_output")
                    )
        ),
                    # and the column with the markdown file
                    column(
                        width = 8,
                        wellPanel(
                            uiOutput("markdown")
                        )
                    )
                    )

)