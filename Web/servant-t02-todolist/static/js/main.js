/**
 * Initialize the application when the DOM is fully loaded
 */
document.addEventListener('DOMContentLoaded', () => {
  showDefaultMessage();
  loadTodos();

  const todoForm = document.getElementById('todo-form');
  todoForm?.addEventListener('submit', handleFormSubmit);
  
  // Set up interval to update relative times every minute
  setInterval(updateRelativeTimes, 60000);
});

/**
 * Update all relative time displays on the page
 */
const updateRelativeTimes = () => {
  const timeElements = document.querySelectorAll('.relative-time[data-timestamp]');
  
  timeElements.forEach(element => {
    const timestamp = element.getAttribute('data-timestamp');
    if (timestamp) {
      element.textContent = formatRelativeTime(timestamp);
    }
  });
}

/**
 * Fetch all todos from the API and display them
 * Handles Haskell's Either type responses (Right for success, Left for errors)
 * @returns {Promise<void>}
 */
const loadTodos = async () => {
  try {
    const response = await fetch('/api/todos');
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const responseText = await response.text();
    
    if (!responseText?.trim()) {
      displayTodos([]);
      return;
    }
    
    try {
      const parsedData = JSON.parse(responseText);
      
      // Extract todos from Either type (Right field) or use directly if it's an array
      const todos = Array.isArray(parsedData) ? parsedData : parsedData?.Right || [];
      
      displayTodos(todos);
    } catch (parseError) {
      console.error('JSON parse error:', parseError);
      showMessage('Error parsing todos data. Please try again.', 'error');
    }
  } catch (error) {
    console.error('Error loading todos:', error);
    showMessage('Error loading todos. Please try again.', 'error');
  }
}

/**
 * Format a timestamp as a relative time string (e.g., '2 minutes ago', '3 hours ago')
 * @param {string} timestamp - ISO timestamp string
 * @returns {string} - Formatted relative time string
 */
const formatRelativeTime = (timestamp) => {
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now - date;
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);
  const diffMonth = Math.floor(diffDay / 30);
  const diffYear = Math.floor(diffMonth / 12);

  // Store the absolute date for tooltip
  const absoluteDate = date.toLocaleString();
  
  if (diffSec < 60) {
    return `${diffSec} second${diffSec !== 1 ? 's' : ''} ago`;
  } else if (diffMin < 60) {
    return `${diffMin} minute${diffMin !== 1 ? 's' : ''} ago`;
  } else if (diffHour < 24) {
    return `${diffHour} hour${diffHour !== 1 ? 's' : ''} ago`;
  } else if (diffDay < 30) {
    return `${diffDay} day${diffDay !== 1 ? 's' : ''} ago`;
  } else if (diffMonth < 12) {
    return `${diffMonth} month${diffMonth !== 1 ? 's' : ''} ago`;
  } else {
    return `${diffYear} year${diffYear !== 1 ? 's' : ''} ago`;
  }
}

/**
 * Display todos in the table
 * @param {Array} todos - Array of todo objects
 */
const displayTodos = (todos) => {
  const tableBody = document.getElementById('todos-table-body');
  if (!tableBody) return;

  tableBody.innerHTML = '';
  
  if (!todos?.length) {
    tableBody.innerHTML = '<tr><td colspan="6">No todos found</td></tr>';
    return;
  }

  const todosHtml = todos.map(({ todoId, todoTitle, createdAt, priority, status }) => {
    // Format the priority with appropriate class
    const priorityClass = `priority-${priority.toLowerCase()}`;
    const priorityDisplay = `<span class="${priorityClass}" data-priority="${priority.toLowerCase()}" data-todo-id="${todoId}" onclick="togglePriority(this)">${priority}</span>`;
    
    // Format the status with appropriate class
    let statusClass, statusText, statusDataAttr;
    
    if (status === 'DoneStatus') {
      statusClass = 'status-completed';
      statusText = 'Done';
      statusDataAttr = 'done';
    } else if (status === 'DoingStatus') {
      statusClass = 'status-doing';
      statusText = 'Doing';
      statusDataAttr = 'doing';
    } else {
      statusClass = 'status-pending';
      statusText = 'Todo';
      statusDataAttr = 'todo';
    }
    
    const statusDisplay = `<span class="${statusClass}" data-status="${statusDataAttr}" data-todo-id="${todoId}" onclick="toggleStatus(this)">${statusText}</span>`;
    
    // Format the date as relative time
    const relativeTime = formatRelativeTime(createdAt);
    const absoluteDate = new Date(createdAt).toLocaleString();
    
    return `
    <tr data-todo-id="${todoId}">
      <td>${todoId}</td>
      <td>${todoTitle}</td>
      <td class="relative-time" data-timestamp="${createdAt}" title="${absoluteDate}">${relativeTime}</td>
      <td>${priorityDisplay}</td>
      <td>${statusDisplay}</td>
      <td>
        <button class="btn" onclick="editTodo(${todoId}, '${todoTitle}', '${priority}', '${status}')">Edit</button>
        <button class="btn btn-danger" onclick="deleteTodo(${todoId})">Delete</button>
      </td>
    </tr>
  `}).join('');
  
  tableBody.innerHTML = todosHtml;
}

/**
 * Handle form submission for creating or updating a todo
 * @param {Event} event - The form submission event
 * @returns {Promise<void>}
 */
const handleFormSubmit = async (event) => {
  event.preventDefault();
  
  const todoId = document.getElementById('todoId').value;
  const todoTitle = document.getElementById('todoTitle').value;
  const todoPriority = document.getElementById('todoPriority').value;
  const todoStatus = document.getElementById('todoStatus').value;
  const formMode = document.getElementById('form-mode').value;
  
  if (!todoTitle?.trim()) {
    showMessage('Please enter a todo title', 'error');
    return;
  }
  
  try {
    const isCreate = formMode === 'create';
    const endpoint = isCreate ? '/api/todos' : `/api/todos/${todoId}`;
    const method = isCreate ? 'POST' : 'PUT';
    
    // We need to send the status as a string value (Todo, Doing, Done)
    // The backend will convert it to the correct enum value
    // No need to map to enum constructor names (TodoStatus, DoingStatus, DoneStatus)
    
    const payload = isCreate 
      ? { newTodoTitle: todoTitle, newTodoPriority: todoPriority }
      : { todoId: parseInt(todoId, 10), todoTitle, priority: todoPriority, status: todoStatus };
    
    const response = await fetch(endpoint, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const data = await response.json();
    
    // Handle Haskell's Either type response (Left for errors)
    if (data.Left) {
      showMessage(`Validation error: ${data.Left.errorMessage || 'Unknown error'}`, 'error');
      return;
    }
    
    // Handle other error formats
    if (data?.errorMessage) {
      showMessage(`Validation error: ${data.errorMessage}`, 'error');
      return;
    }
    
    resetForm();
    loadTodos();
    
    const successMessage = isCreate ? 'Todo created successfully!' : 'Todo updated successfully!';
    showMessage(successMessage, 'success');
  } catch (error) {
    console.error('Error:', error);
    showMessage(`Error: ${error.message}`, 'error');
  }
}

/**
 * Set up form for creating a new todo
 */
const setupCreateForm = () => {
  document.getElementById('form-title').textContent = 'Create New Todo';
  document.getElementById('form-mode').value = 'create';
  document.getElementById('todoId').value = '';
  document.getElementById('todoTitle').value = '';
  document.getElementById('todoPriority').value = 'Medium';
  document.getElementById('todoStatus').value = 'Todo';
  document.getElementById('status-group').style.display = 'flex';
  document.getElementById('submit-btn').textContent = 'Create Todo';
}

/**
 * Set up form for editing an existing todo
 * @param {number} todoId - ID of the todo to edit
 * @param {string} todoTitle - Title of the todo to edit
 */
const editTodo = (todoId, todoTitle, priority, status) => {
  document.getElementById('form-title').textContent = 'Edit Todo';
  document.getElementById('form-mode').value = 'update';
  document.getElementById('todoId').setAttribute('readonly', 'readonly');
  document.getElementById('todoId').value = todoId;
  document.getElementById('todoTitle').value = todoTitle;
  document.getElementById('todoPriority').value = priority;
  
  // Parse the status string to get the actual status value
  let statusValue = 'Todo';
  if (status === 'DoneStatus') {
    statusValue = 'Done';
  } else if (status === 'DoingStatus') {
    statusValue = 'Doing';
  }
  document.getElementById('todoStatus').value = statusValue;
  document.getElementById('status-group').style.display = 'flex';
  document.getElementById('submit-btn').textContent = 'Update Todo';
  
  // Scroll to form
  document.getElementById('todo-form').scrollIntoView({ behavior: 'smooth' });
}

/**
 * Delete a todo by ID
 * @param {number} todoId - ID of the todo to delete
 * @returns {Promise<void>}
 */
const deleteTodo = async (todoId) => {
  if (!confirm(`Are you sure you want to delete todo with ID ${todoId}?`)) {
    return;
  }
  
  try {
    const response = await fetch(`/api/todos/${todoId}`, {
      method: 'DELETE'
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    loadTodos();
    showMessage('Todo deleted successfully!', 'success');
  } catch (error) {
    console.error('Error deleting todo:', error);
    showMessage(`Error deleting todo: ${error.message}`, 'error');
  }
}

/**
 * Reset the form to its initial state
 */
const resetForm = () => {
  setupCreateForm();
  showDefaultMessage();
}

/**
 * Show a message to the user
 * @param {string} message - Message to display
 * @param {string} type - Message type ('error' or 'success')
 */
const showMessage = (message, type) => {
  const messageContainer = document.getElementById('message-container');
  if (!messageContainer) return;
  
  const alertClass = type === 'error' ? 'alert-danger' : 'alert-success';
  
  messageContainer.innerHTML = `
    <div class="alert ${alertClass}">
      ${message}
    </div>
  `;
  
  // Clear the message after 5 seconds and show default message
  setTimeout(showDefaultMessage, 5000);
}

/**
 * Show the default message
 */
/**
 * Toggle the status of a todo item (Todo -> Doing -> Done -> Todo)
 * @param {HTMLElement} element - The status element that was clicked
 */
const toggleStatus = async (element) => {
  const todoId = element.getAttribute('data-todo-id');
  const currentStatus = element.getAttribute('data-status');
  
  if (!todoId) return;
  if (!element.closest('tr')) return;
  
  try {
    const response = await fetch(`/api/todos/${todoId}`);
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const todos = await response.json();
    if (!todos || !todos.length) {
      throw new Error('Todo not found');
    }
    
    const todo = JSON.parse(JSON.stringify(todos[0]));
    
    let newStatus, statusValue, statusClass, statusText;
    
    if (currentStatus === 'todo') {
      newStatus = 'doing';
      statusValue = 'DoingStatus';
      statusClass = 'status-doing';
      statusText = 'Doing';
    } else if (currentStatus === 'doing') {
      newStatus = 'done';
      statusValue = 'DoneStatus';
      statusClass = 'status-completed';
      statusText = 'Done';
    } else {
      newStatus = 'todo';
      statusValue = 'TodoStatus';
      statusClass = 'status-pending';
      statusText = 'Todo';
    }
    
    const updatedTodo = {
      ...todo,
      status: statusValue
    };
    
    const updateResponse = await fetch(`/api/todos/${todoId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updatedTodo)
    });
    
    if (!updateResponse.ok) {
      throw new Error(`HTTP error! Status: ${updateResponse.status}`);
    }
    
    element.className = statusClass;
    element.setAttribute('data-status', newStatus);
    element.textContent = statusText;
    
    showMessage(`Todo status updated to ${statusText}`, 'success');
  } catch (error) {
    console.error('Error updating todo status:', error);
    showMessage(`Error updating todo status: ${error.message}`, 'error');
  }
}

/**
 * Toggle the priority of a todo item (Low -> Medium -> High -> Low)
 * @param {HTMLElement} element - The priority element that was clicked
 */
const togglePriority = async (element) => {
  const todoId = element.getAttribute('data-todo-id');
  const currentPriority = element.getAttribute('data-priority');
  
  if (!todoId) return;
  if (!element.closest('tr')) return;
  
  try {
    const response = await fetch(`/api/todos/${todoId}`);
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const todos = await response.json();
    if (!todos || !todos.length) {
      throw new Error('Todo not found');
    }
    
    // Get the todo object
    const todo = todos[0];
    
    // Determine the next priority
    let newPriority, priorityValue, priorityClass, priorityText;
    
    if (currentPriority === 'low') {
      // Low -> Medium
      newPriority = 'medium';
      priorityValue = 'Medium';
      priorityClass = 'priority-medium';
      priorityText = 'Medium';
    } else if (currentPriority === 'medium') {
      // Medium -> High
      newPriority = 'high';
      priorityValue = 'High';
      priorityClass = 'priority-high';
      priorityText = 'High';
    } else {
      // High -> Low
      newPriority = 'low';
      priorityValue = 'Low';
      priorityClass = 'priority-low';
      priorityText = 'Low';
    }
    
    // Ensure status is in the correct format expected by the server
    // The server expects 'TodoStatus', 'DoingStatus', or 'DoneStatus'
    let statusValue = todo.status;
    if (statusValue === 'Todo') {
      statusValue = 'TodoStatus';
    } else if (statusValue === 'Doing') {
      statusValue = 'DoingStatus';
    } else if (statusValue === 'Done') {
      statusValue = 'DoneStatus';
    }
    
    // Create the updated todo with all required fields
    const updatedTodo = {
      todoId: todo.todoId,
      todoTitle: todo.todoTitle,
      createdAt: todo.createdAt,
      priority: priorityValue,
      status: statusValue
    };
    
    console.log('Sending update:', JSON.stringify(updatedTodo));
    
    const updateResponse = await fetch(`/api/todos/${todoId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(updatedTodo)
    });
    
    if (!updateResponse.ok) {
      const errorText = await updateResponse.text();
      throw new Error(`HTTP error! Status: ${updateResponse.status}, Details: ${errorText}`);
    }
    
    // Update the UI without reloading the entire list
    element.className = priorityClass;
    element.setAttribute('data-priority', newPriority);
    element.textContent = priorityText;
    
    showMessage(`Todo priority updated to ${priorityText}`, 'success');
  } catch (error) {
    console.error('Error updating todo priority:', error);
    showMessage(`Error updating todo priority: ${error.message}`, 'error');
  }
}

const showDefaultMessage = () => {
  const messageContainer = document.getElementById('message-container');
  if (!messageContainer) return;
  
  messageContainer.innerHTML = `
    <div class="alert alert-info">
      Add your new Todo or search for an existing Todo
    </div>
  `;
}
