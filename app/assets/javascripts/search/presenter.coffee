# Frontend Search Implementation - Presenter
# The presenter handles communication between the view and the model.
# It's like a rails Controller, but also handles requests from the view (JS
# callbacks)
# Patterns: Single Instance; Model-Template-Presenter-ViewModel structure
class Clarat.Search.Presenter extends ActiveScript.Presenter
  # This SubApplication sits inside the RoR Offers#index
  constructor: ->
    super()

    @model = Clarat.Search.Model.load()
    @searchFramework()


  ### "CREATE ACTION" ###

  ###
  Sending a search means that we compile the available parameters into
  a search query and instead of sending (saving) it to our database, we send
  it to a remote search index, which returns aus the completed search objects
  for the onMainResults view. That means #onMainResults can't be called directly
  without #sendMainSearch as it's not persisted.
  ###
  sendMainSearch: =>
    @model.getMainSearchResults().then(@onMainResults).catch(@failure)

  sendLocationSupportSearch: =>
    @model.getLocationSupportResults().then(@onLocationSupportResults).catch(
      @failure
    )

  sendQuerySupportSearch: =>
    @model.getQuerySupportResults().then(@onQuerySupportResults).catch(
      @failure
    )


  ### "SHOW ACTIONS" ###

  # Renders a mostly empty wireframe that the search results will be placed in.
  searchFramework: ->
    @render '#search-wrapper', 'search', new Clarat.Search.Cell.Search(@model)
    Clarat.Search.Operation.UpdateCategories.updateActiveClasses @model.category
    Clarat.Search.Operation.UpdateAdvancedSearch.run @model
    new Clarat.MapModal.Presenter # handles Map Button

  # Rendered upon successful sendMainSearch.
  onMainResults: (resultSet) =>
    viewModel = new Clarat.Search.Cell.SearchResults resultSet, @model

    @render '.Listing-results', 'search_results', viewModel
    if @model.isPersonal()
      Clarat.Search.Operation.BuildMap.run viewModel.main_offers

  # Support Results only change when location changes. TODO: facets?
  onLocationSupportResults: (resultSet) =>
    nearbyResults = resultSet.results[0]
    personalFacetResults = resultSet.results[1]
    remoteFacetResults = resultSet.results[2]

    if nearbyResults.nbHits < 1
      Clarat.Modal.open('#unavailable_location_overlay')

    Clarat.Search.Operation.UpdateCategories.updateCounts(
      personalFacetResults, remoteFacetResults
    )

  onQuerySupportResults: (resultSet) =>
    personalFacetResults = resultSet.results[0]
    remoteFacetResults = resultSet.results[1]
    Clarat.Search.Operation.UpdateCategories.updateCounts(
      personalFacetResults, remoteFacetResults
    )


  ### CALLBACKS ###

  CALLBACKS:
    '#search_form_query':
      keyup: 'handleQueryKeyUp'
      change: 'handleQueryChange'
    'document':
      'Clarat.Location::NewLocation': 'handleNewGeolocation'
    '.JS-RemoveQueryLink':
      click: 'handleRemoveQueryClick'
    '.JS-CategoryLink':
      click: 'handleCategoryClick'
    '.JS-ToggleContactType':
      click: 'handleToggleContactTypeClick'
    '.JS-PaginationLink':
      click: 'handlePaginationClick'

    '#advanced_search .JS-AgeSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-TargetAudienceSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-ExclusiveGenderSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-LanguageSelector':
      change: 'handleFilterChange'
    '#advanced_search .JS-ContactTypeSelector':
      change: 'handleFilterChange'

  handleQueryKeyUp: (event) =>
    @model.assignAttributes query: event.target.value
    @sendMainSearch()
    @sendQuerySupportSearch()

  # We don't want to update all the time when user is typing. Persistence only
  # happens when they are done (and this fires). No need to send new search.
  handleQueryChange: (event) =>
    @model.updateAttributes query: event.target.value
    @sendQuerySupportSearch()

  handleNewGeolocation: (event, location) =>
    @model.updateAttributes
      search_location: location.query
      generated_geolocation: location.geoloc
    @sendMainSearch()
    @sendLocationSupportSearch() # only needs to be called on new location

  handleRemoveQueryClick: (event) =>
    @model.updateAttributes query: ''
    @sendMainSearch()
    @sendQuerySupportSearch()

  handleCategoryClick: (event) =>
    categoryName = $(event.target).data('name')
    @model.updateAttributes category: categoryName
    Clarat.Search.Operation.UpdateCategories.updateActiveClasses categoryName
    @sendMainSearch()
    @stopEvent event

  handleToggleContactTypeClick: (event) =>
    if @model.isPersonal()
      @model.updateAttributes contact_type: 'remote'
      $('.aside-standard').hide()
      $('#contact_type_remote').prop('checked', true)
    else
      @model.updateAttributes contact_type: 'personal'
      $('.aside-standard').show()
      $('#contact_type_personal').prop('checked', true)
    @sendMainSearch()
    @stopEvent event

  handlePaginationClick: (event) =>
    @model.updateAttributes page: ($(event.target).data('page') - 1)
    @sendMainSearch()
    @stopEvent event

  handleFilterChange: (event) =>
    val = $(event.target).val()
    val = if val is 'any' then '' else val
    field = $(event.target).parent('fieldset').attr('id')

    @model.updateAttributes "#{field}": val
    @sendMainSearch()

  # Error view, rendered in case of any sendMainSearch/onMainResults exceptions.
  failure: (error) =>
    console.log error
    @render '#search-wrapper', 'error_ajax', I18n.t('js.ajax_error')
