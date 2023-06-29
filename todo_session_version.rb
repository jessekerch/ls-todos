require "pry"
require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :sessions_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def list_completed?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_completed?(list)
  end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def todos_remaining_count(list)
    list[:todos].count {|todo| !todo[:completed]}
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    incomplete_lists = {}
    complete_lists = {}

    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }

    incomplete_lists.each { |list| yield list }
    complete_lists.each  { |list| yield list }
  end

  def sort_todos(todos, &block)
    incomplete_todos = {}
    complete_todos = {}

    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo }
    complete_todos.each  { |todo| yield todo }
  end

  def get_next_id(elements)
    max = elements.map { |ele| ele[:id] }.max || 0
    max + 1
  end
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]

  erb :lists, layout: :layout
end

# Render a new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Return error message if list name invalid, nil if valid
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? {|list| list[:name] == name}
    "List name must be unique."
  end
end

# Return error message if list name invalid, nil if valid
def error_for_todo_name(name)
  if !(1..100).cover? name.size
    "Todo must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = get_next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

def load_list(num)
  list = session[:lists].find {|list| list[:id] == num }
  return list if list

  session[:error] = "The requested list does not exist."
  redirect "/lists"
end

# View to do items on a list
get "/lists/:list_num" do
  list_num = params[:list_num].to_i
  @list = load_list(list_num)

  erb :list_detail, layout: :layout
end

# Get page to edit a list name
get "/lists/:list_num/edit" do
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  erb :edit_list, layout: :layout
end

# Edit a list name
post "/lists/:list_num" do
  list_name = params[:list_name].strip
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list name has been updated."
    redirect "/lists/#{@list_num}"
  end
end

# Delete a list
post "/lists/:list_num/delete" do
  list_num = params[:list_num].to_i
  session[:lists].reject! { |list| list[:id] == list_num }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Add a new todo to a list
post "/lists/:list_num/todos" do
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)

  if error
    session[:error] = error
    erb :list_detail, layout: :layout
  else
    id = get_next_id(@list[:todos])
    @list[:todos] << {id: id, name: todo_name, completed: false}

    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_num}"
  end
end

# Delete a todo
post "/lists/:list_num/todos/:todo_num/delete" do
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  todo_num = params[:todo_num].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_num }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax request
    status 204
  else
    session[:success] = "Todo has been deleted."
    redirect "/lists/#{@list_num}"
  end

end

# Check or uncheck a todo checkbox
post "/lists/:list_num/todos/:todo_num" do
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  todo_num = params[:todo_num].to_i
  checked = params[:completed] == "true"
  todo = @list[:todos].find { |todo| todo[:id] == todo_num }
  todo[:completed] = checked

  session[:success] = "Todo item has been updated."
  redirect "/lists/#{@list_num}"
end

# Check all todo checkboxes
post "/lists/:list_num/completeall" do
  @list_num = params[:list_num].to_i
  @list = load_list(@list_num)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todo items have been completed."
  redirect "/lists/#{@list_num}"
end
