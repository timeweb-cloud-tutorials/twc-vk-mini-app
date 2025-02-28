import React, { useState, useEffect } from 'react';
import {
  AppRoot,
  SplitLayout,
  SplitCol,
  View,
  Panel,
  PanelHeader,
  Group,
  Div,
  Spinner,
  ScreenSpinner,
  Snackbar,
  Avatar,
  Header
} from '@vkontakte/vkui';
import '@vkontakte/vkui/dist/vkui.css';
import { Icon16Done, Icon16Cancel } from '@vkontakte/icons';

import { getTasks, addTask, deleteTask } from './api';
import EisenhowerMatrix from './components/EisenhowerMatrix';
import AddTaskForm from './components/AddTaskForm';

const App = () => {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [popout, setPopout] = useState(null);
  const [snackbar, setSnackbar] = useState(null);

  // Загрузка задач при монтировании компонента
  useEffect(() => {
    fetchTasks();
  }, []);

  // Функция для загрузки задач с сервера
  const fetchTasks = async () => {
    try {
      setLoading(true);
      const data = await getTasks();
      setTasks(data);
    } catch (error) {
      showError('Не удалось загрузить задачи');
    } finally {
      setLoading(false);
    }
  };

  // Функция для добавления новой задачи
  const handleAddTask = async (title, urgent, important) => {
    try {
      setPopout(<ScreenSpinner />);
      const response = await addTask(title, urgent, important);
      setTasks([...tasks, response.task]);
      showSuccess('Задача успешно добавлена');
    } catch (error) {
      showError('Не удалось добавить задачу');
    } finally {
      setPopout(null);
    }
  };

  // Функция для удаления задачи
  const handleDeleteTask = async (taskId) => {
    try {
      setPopout(<ScreenSpinner />);
      await deleteTask(taskId);
      setTasks(tasks.filter(task => task.id !== taskId));
      showSuccess('Задача успешно удалена');
    } catch (error) {
      showError('Не удалось удалить задачу');
    } finally {
      setPopout(null);
    }
  };

  // Функция для отображения сообщения об успехе
  const showSuccess = (text) => {
    setSnackbar(
      <Snackbar
        onClose={() => setSnackbar(null)}
        before={<Avatar size={24} style={{ background: 'var(--accent)' }}><Icon16Done fill="#fff" width={14} height={14} /></Avatar>}
      >
        {text}
      </Snackbar>
    );
  };

  // Функция для отображения сообщения об ошибке
  const showError = (text) => {
    setSnackbar(
      <Snackbar
        onClose={() => setSnackbar(null)}
        before={<Avatar size={24} style={{ background: 'var(--destructive)' }}><Icon16Cancel fill="#fff" width={14} height={14} /></Avatar>}
      >
        {text}
      </Snackbar>
    );
  };

  return (
    <AppRoot>
      <SplitLayout popout={popout}>
        <SplitCol>
          <View activePanel="main">
            <Panel id="main">
              <PanelHeader>Матрица Эйзенхауэра</PanelHeader>
              
              <Group header={<Header mode="secondary">Добавить новую задачу</Header>}>
                <AddTaskForm onAddTask={handleAddTask} />
              </Group>
              
              <Group header={<Header mode="secondary">Ваши задачи</Header>}>
                {loading ? (
                  <Div style={{ display: 'flex', justifyContent: 'center' }}>
                    <Spinner size="medium" />
                  </Div>
                ) : (
                  <EisenhowerMatrix tasks={tasks} onDeleteTask={handleDeleteTask} />
                )}
              </Group>
            </Panel>
          </View>
        </SplitCol>
      </SplitLayout>
      {snackbar}
    </AppRoot>
  );
};

export default App;
