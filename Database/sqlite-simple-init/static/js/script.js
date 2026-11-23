document.addEventListener('DOMContentLoaded', function() {
    const userForm = document.getElementById('userForm');
    const userId = document.getElementById('userId');
    const nameInput = document.getElementById('name');
    const emailInput = document.getElementById('email');
    const passwordInput = document.getElementById('password');
    const saveBtn = document.getElementById('saveBtn');
    const cancelBtn = document.getElementById('cancelBtn');
    const usersTableBody = document.getElementById('usersTableBody');

    loadUsers();

    userForm.addEventListener('submit', saveUser);
    cancelBtn.addEventListener('click', resetForm);

    function loadUsers() {
        fetch('/users')
            .then(response => response.json())
            .then(users => {
                usersTableBody.innerHTML = '';
                users.forEach(user => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${user.userId || ''}</td>
                        <td>${user.userName}</td>
                        <td>${user.userEmail}</td>
                        <td>
                            <button class="action-btn view-btn" data-id="${user.userId}">View</button>
                            <button class="action-btn edit-btn" data-id="${user.userId}">Edit</button>
                            <button class="action-btn delete-btn" data-id="${user.userId}">Delete</button>
                        </td>
                    `;
                    usersTableBody.appendChild(row);
                });

                document.querySelectorAll('.view-btn').forEach(btn => {
                    btn.addEventListener('click', () => viewUser(btn.dataset.id));
                });
                document.querySelectorAll('.edit-btn').forEach(btn => {
                    btn.addEventListener('click', () => editUser(btn.dataset.id));
                });
                document.querySelectorAll('.delete-btn').forEach(btn => {
                    btn.addEventListener('click', () => deleteUser(btn.dataset.id));
                });
            })
            .catch(error => console.error('Error loading users:', error));
    }

    function viewUser(id) {
        fetch(`/users/${id}`)
            .then(response => {
                if (!response.ok) {
                    throw new Error('User not found');
                }
                return response.json();
            })
            .then(user => {
                alert(`User Details:\nID: ${user.userId}\nName: ${user.userName}\nEmail: ${user.userEmail}\nCreated: ${new Date(user.createdAt).toLocaleString()}\nUpdated: ${new Date(user.updatedAt).toLocaleString()}`);
            })
            .catch(error => console.error('Error viewing user:', error));
    }

    function editUser(id) {
        fetch(`/users/${id}`)
            .then(response => {
                if (!response.ok) {
                    throw new Error('User not found');
                }
                return response.json();
            })
            .then(user => {
                userId.value = user.userId;
                nameInput.value = user.userName;
                emailInput.value = user.userEmail;
                passwordInput.value = user.userPassword;
                saveBtn.textContent = 'Update';
            })
            .catch(error => console.error('Error editing user:', error));
    }

    function saveUser(event) {
        event.preventDefault();
        
        const user = {
            name: nameInput.value,
            email: emailInput.value,
            password: passwordInput.value
        };

        const id = userId.value;
        const method = id ? 'PUT' : 'POST';
        const url = id ? `/users/${id}` : '/users';

        const formData = new URLSearchParams();
        Object.keys(user).forEach(key => formData.append(key, user[key]));

        fetch(url, {
            method: method,
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: formData
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Failed to save user');
            }
            return response.json();
        })
        .then(data => {
            resetForm();
            loadUsers();
            alert(id ? 'User updated successfully!' : 'User created successfully!');
        })
        .catch(error => {
            console.error('Error saving user:', error);
            alert('Error: ' + error.message);
        });
    }

    function deleteUser(id) {
        if (confirm('Are you sure you want to delete this user?')) {
            fetch(`/users/${id}`, {
                method: 'DELETE'
            })
            .then(response => {
                if (!response.ok) {
                    throw new Error('Failed to delete user');
                }
                loadUsers();
                alert('User deleted successfully!');
            })
            .catch(error => console.error('Error deleting user:', error));
        }
    }

    function resetForm() {
        userId.value = '';
        userForm.reset();
        saveBtn.textContent = 'Save';
    }
});
