document.addEventListener('DOMContentLoaded', function() {
  // Load all users when the page loads
  loadUsers();

  // Set up event listeners
  const userForm = document.getElementById('user-form');
  if (userForm) {
    userForm.addEventListener('submit', handleFormSubmit);
  }
});

// Function to load all users from the API
async function loadUsers() {
  try {
    const response = await fetch('/users');
    const users = await response.json();
    displayUsers(users);
  } catch (error) {
    console.error('Error loading users:', error);
    showMessage('Error loading users. Please try again.', 'error');
  }
}

// Function to display users in the table
function displayUsers(users) {
  const tableBody = document.getElementById('users-table-body');
  if (!tableBody) return;

  tableBody.innerHTML = '';
  
  if (users.length === 0) {
    const row = document.createElement('tr');
    row.innerHTML = '<td colspan="4">No users found</td>';
    tableBody.appendChild(row);
    return;
  }

  users.forEach(user => {
    const row = document.createElement('tr');
    row.innerHTML = `
      <td>${user.userId}</td>
      <td>${user.userName}</td>
      <td>
        <button class="btn" onclick="editUser(${user.userId}, '${user.userName}')">Edit</button>
        <button class="btn btn-danger" onclick="deleteUser(${user.userId})">Delete</button>
      </td>
    `;
    tableBody.appendChild(row);
  });
}

// Function to handle form submission (create or update user)
async function handleFormSubmit(event) {
  event.preventDefault();
  
  const userId = document.getElementById('userId').value;
  const userName = document.getElementById('userName').value;
  
  if (!userName) {
    showMessage('Please enter a user name', 'error');
    return;
  }
  
  const formMode = document.getElementById('form-mode').value;
  
  try {
    let response;
    
    if (formMode === 'create') {
      // For creation, we only need userName as userId is auto-generated
      const newUserData = {
        newUserName: userName
      };
      
      response = await fetch('/users', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(newUserData)
      });
    } else if (formMode === 'update') {
      // For updates, we need both userId and userName
      const userData = {
        userId: parseInt(userId),
        userName: userName
      };
      
      response = await fetch(`/users/${userId}`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(userData)
      });
    }
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    // Parse the response
    const data = await response.json();
    
    // Check if there's a validation error (Aeson serializes Either as {Left: ...} or {Right: ...})
    if (data && data.Left) {
      showMessage(`Validation error: ${data.Left.errorMessage}`, 'error');
      return;
    }

    // Reset form
    resetForm();

    // Reload users
    loadUsers();
    
    showMessage(formMode === 'create' ? 'User created successfully!' : 'User updated successfully!', 'success');
  } catch (error) {
    console.error('Error:', error);
    showMessage(`Error: ${error.message}`, 'error');
  }
}

// Function to set up form for creating a new user
function setupCreateForm() {
  document.getElementById('form-title').textContent = 'Create New User';
  document.getElementById('form-mode').value = 'create';
  document.getElementById('userId').value = '';
  document.getElementById('userName').value = '';
  document.getElementById('submit-btn').textContent = 'Create User';
}

// Function to set up form for editing a user
function editUser(userId, userName) {
  document.getElementById('form-title').textContent = 'Edit User';
  document.getElementById('form-mode').value = 'update';
  document.getElementById('userId').setAttribute('readonly', 'readonly');
  document.getElementById('userId').value = userId;
  document.getElementById('userName').value = userName;
  document.getElementById('submit-btn').textContent = 'Update User';
  
  // Scroll to form
  document.getElementById('user-form').scrollIntoView({ behavior: 'smooth' });
}

// Function to delete a user
async function deleteUser(userId) {
  if (!confirm(`Are you sure you want to delete user with ID ${userId}?`)) {
    return;
  }
  
  try {
    const response = await fetch(`/users/${userId}`, {
      method: 'DELETE'
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    loadUsers();
    showMessage('User deleted successfully!', 'success');
  } catch (error) {
    console.error('Error deleting user:', error);
    showMessage(`Error deleting user: ${error.message}`, 'error');
  }
}

// Function to reset the form
function resetForm() {
  setupCreateForm();
}

// Function to show a message to the user
function showMessage(message, type) {
  const messageContainer = document.getElementById('message-container');
  if (!messageContainer) return;
  
  const alertClass = type === 'error' ? 'alert-danger' : 'alert-success';
  
  messageContainer.innerHTML = `
    <div class="alert ${alertClass}">
      ${message}
    </div>
  `;
  
  // Clear the message after 5 seconds
  setTimeout(() => {
    messageContainer.innerHTML = '';
  }, 5000);
}
