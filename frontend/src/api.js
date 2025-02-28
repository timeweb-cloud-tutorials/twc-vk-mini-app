import axios from 'axios';

// Для разработки используем localhost, для продакшена - относительный путь /api
const devApi = "http://localhost:8000";
const prodApi = "/api"; // Теперь используем относительный путь /api вместо http://backend:8000

// Определяем базовый URL в зависимости от окружения
export const BASE_URL = process.env.NODE_ENV === "development" ? devApi : prodApi;

// Создаем экземпляр axios с базовым URL
const api = axios.create({
  baseURL: BASE_URL,
});

// Функция для получения всех задач
export const getTasks = async () => {
  try {
    const response = await api.get('/tasks');
    return response.data;
  } catch (error) {
    console.error('Error fetching tasks:', error);
    throw error;
  }
};

// Функция для добавления новой задачи
export const addTask = async (title, urgent, important) => {
  try {
    const response = await api.post(`/tasks?title=${encodeURIComponent(title)}&urgent=${urgent}&important=${important}`);
    return response.data;
  } catch (error) {
    console.error('Error adding task:', error);
    throw error;
  }
};

// Функция для удаления задачи
export const deleteTask = async (taskId) => {
  try {
    const response = await api.delete(`/tasks/${taskId}`);
    return response.data;
  } catch (error) {
    console.error('Error deleting task:', error);
    throw error;
  }
};
