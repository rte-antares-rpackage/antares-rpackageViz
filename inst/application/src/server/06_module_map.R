# list of opts for set layout
layout <- reactive({
  ind_keep_list_data <- ind_keep_list_data()
  isolate({
    if(!is.null(ind_keep_list_data)){
      ind_map <- unique(sort(c(ind_keep_list_data$ind_areas, ind_keep_list_data$ind_links)))
      if(length(ind_map) > 0){
        if(packageVersion("antaresRead") <= '2.0.0'){
          readLayout(opts = list_data_all$opts[ind_map][[1]])
        } else {
          
          tmp <- tryCatch(readLayout(opts = list_data_all$opts[ind_map]), 
                          error = function(e) return(readLayout(opts = list_data_all$opts)))
          tmp
        }
      }else{
        NULL
      }
    } else {
      NULL
    }
  })
})

ml <- reactiveVal()
# module for set and save layout
map_language <- reactive({
  current_language$language
})

ml_builder <- callModule(antaresViz:::changeCoordsServer, "ml", layout, 
                         what = reactive("areas"), language = map_language, stopApp = FALSE)

observe({
  ml(ml_builder())
})

observe({
  ml_file <- input$import_layout
  if (!is.null(ml_file)){
    tmp_ml <- try(readRDS(ml_file$datapath), silent = TRUE)
    if("mapLayout" %in% class(tmp_ml)){
      ml(tmp_ml)
    } else {
      showModal(modalDialog(
        title = "Invalid map layout file",
        easyClose = TRUE,
        footer = NULL,
        "Must be a valid .RDS file (class 'mapLayout')"
      ))
    }
  }
})

# control : have a not null layout, and so print map module ?
print_map <- reactiveValues(value = FALSE)

observe({
  if(!is.null(ml())){
    print_map$value <- TRUE
  } else {
    print_map$value <- FALSE
  }
})


output$current_layout <- renderLeafletDragPoints({
  if(!is.null(ml())){
    plotMapLayout(ml())
  }
})

output$must_print_map <- reactive({
  print_map$value
})

outputOptions(output, "must_print_map", suspendWhenHidden = FALSE)

observe({
  ml <- ml()
  ind_keep_list_data <- ind_keep_list_data()
  language <- current_language$language
  isolate({
    if(input$update_module > 0){
      if(!is.null(ind_keep_list_data)){
        ind_map <- unique(sort(c(ind_keep_list_data$ind_areas, ind_keep_list_data$ind_links)))
        if(length(ind_map) > 0){
          if(!is.null(ml)){
            refStudy <- ind_keep_list_data$refStudy
            
            # init / re-init module plotMap
            id_plotMap   <- paste0("plotMap_", round(runif(1, 1, 100000000)))
            
            # update shared input table
            input_data$data[grepl("^plotMap", input_id), input_id := paste0(id_plotMap, "-shared_", input)]
            
            output[["plotMap_ui"]] <- renderUI({
              mwModuleUI(id = id_plotMap, height = "800px")
            })
            
            .compare <- input$sel_compare_plotMap
            if(input$sel_compare_mcyear){
              .compare <- unique(c(.compare, "mcYear"))
            }
            
            if(length(.compare) > 0){
              list_compare <- vector("list", length(.compare))
              names(list_compare) <- .compare
              # set main with study names
              # if(length(ind_map) != 1){
              #   list_compare$main <- names(list_data_all$antaresDataList[ind_map])
              # }
              .compare <- list_compare
            } else {
              .compare = NULL
            }
            mod_plotMap <- plotMap(x = list_data_all$antaresDataList[ind_map], 
                                   refStudy = refStudy,
                                   mapLayout = ml, 
                                   interactive = TRUE, .updateBtn = TRUE, 
                                   .updateBtnInit = TRUE, compare = .compare,
                                   language = language,
                                   #export with webshot dont work with leaflet and mapLayout
                                   .exportBtn = FALSE,
                                   h5requestFiltering = list_data_all$params[ind_map],
                                   xyCompare = "union", 
                                   .runApp = FALSE)
            
            if("MWController" %in% class(modules$plotMap)){
              modules$plotMap$clear()
            }
            
            modules$plotMap <- mod_plotMap
            modules$id_plotMap <- id_plotMap
            modules$init_plotMap <- TRUE
            # save data and params
            list_data_controls$n_maps <- length(ind_map)
          }
        }
      }
    }
  })
})

observe({
  modules$init_plotMap
  if(input[['map_panel']] == "<div id=\"label_tab_map_viz\" class=\"shiny-text-output\"></div>"){
    isolate({
      if("MWController" %in% class(modules$plotMap) & modules$init_plotMap){
        modules$plotMap <- mwModule(id = modules$id_plotMap,  modules$plotMap)
        modules$init_plotMap <- FALSE
      }
    })
  }
})

# download layout
output$download_layout <- downloadHandler(
  filename = function() {
    paste('mapLayout-', Sys.Date(), '.RDS', sep='')
  },
  content = function(con) {
    saveRDS(ml(), file = con)
  }
)

# change page
observe({
  if(!is.null(input[['ml-done']])){
    if(input[['ml-done']] > 0){
      updateNavbarPage(session, inputId = "map_panel", selected = "<div id=\"label_tab_map_viz\" class=\"shiny-text-output\"></div>")
    }
  }
})