server = function(input, output, session) {

progress <- reactiveValues(message = "", value = 0)

 topic_prompt = eventReactive(
        input$generate_story,
        {
                input$topic
        }
 )

 image_pre_prompt = eventReactive(
        input$generate_story,
        {
                input$image_pre_prompt
        }
 )

    # we want the return of the function "get_story" to be
     # using the arguments input by the user
    story <- reactive(
        {

            print("making story")
            out = get_story(
                OPENAI_API_KEY = Sys.getenv("OAI_API_KEY"),
                chapters = input$chapters,
                words_per_chapter = input$words_per_chapter,
                date = lubridate::today(),
                topic = topic_prompt(),
                prompt = NULL,
                progress = progress,
                model = input$model
            )

            print("done making story")

            return(out)
        }
    )

    # same for the return value of the function "compile_story"
    tex <- reactive(
        {
            print("compiling story")

            out = compile_story(
                story(),
                          image_pre_prompt = image_pre_prompt(),
                          create_images = input$create_images,
                          #create_pdf = input$create_pdf,
                          create_pdf = TRUE,
                          folder = tempdir(),
                          progress = progress
            )

            print("done compilng story")

            return(out)
        }
    )

    # make a download button for the pdf
    output$download_pdf <- downloadHandler(
        filename = function() {
            "story.pdf"
        },
        content = function(file) {
            file.copy(tex()$pdf, file)
        }
    )

    # now we want to render the markdown file
        output$markdown = renderUI(HTML(markdownToHTML(tex()$markdown)))

    output$progress_output <- renderText({
  progress$message
})

    }
