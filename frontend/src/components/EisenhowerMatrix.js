import React from 'react';
import { Group, Card, CardGrid, Text, Div, Button, IconButton } from '@vkontakte/vkui';
import { Icon24DeleteOutline } from '@vkontakte/icons';

const EisenhowerMatrix = ({ tasks, onDeleteTask }) => {
  // Разделяем задачи по квадрантам
  const urgentImportant = tasks.filter(task => task.urgent && task.important);
  const urgentNotImportant = tasks.filter(task => task.urgent && !task.important);
  const notUrgentImportant = tasks.filter(task => !task.urgent && task.important);
  const notUrgentNotImportant = tasks.filter(task => !task.urgent && !task.important);

  // Компонент для отображения задачи
  const TaskItem = ({ task }) => (
    <Card mode="shadow" style={{ marginBottom: 10 }}>
      <Div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Text weight="regular">{task.title}</Text>
        <IconButton onClick={() => onDeleteTask(task.id)}>
          <Icon24DeleteOutline />
        </IconButton>
      </Div>
    </Card>
  );

  // Компонент для отображения квадранта
  const Quadrant = ({ title, description, tasks, color }) => (
    <Card mode="outline" style={{ 
      height: '100%', 
      backgroundColor: color,
      display: 'flex',
      flexDirection: 'column'
    }}>
      <Div>
        <Text weight="semibold" style={{ marginBottom: 8 }}>{title}</Text>
        <Text weight="regular" style={{ color: 'var(--text_secondary)', marginBottom: 16 }}>
          {description}
        </Text>
        <div>
          {tasks.map(task => (
            <TaskItem key={task.id} task={task} />
          ))}
        </div>
      </Div>
    </Card>
  );

  return (
    <Group>
      <Div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gridGap: 16, marginBottom: 16 }}>
          <Quadrant
            title="Срочно и Важно"
            description="Сделать немедленно"
            tasks={urgentImportant}
            color="rgba(255, 99, 71, 0.1)"
          />
          <Quadrant
            title="Не срочно, но Важно"
            description="Запланировать время"
            tasks={notUrgentImportant}
            color="rgba(255, 215, 0, 0.1)"
          />
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gridGap: 16 }}>
          <Quadrant
            title="Срочно, но Не важно"
            description="Делегировать"
            tasks={urgentNotImportant}
            color="rgba(135, 206, 250, 0.1)"
          />
          <Quadrant
            title="Не срочно и Не важно"
            description="Исключить"
            tasks={notUrgentNotImportant}
            color="rgba(144, 238, 144, 0.1)"
          />
        </div>
      </Div>
    </Group>
  );
};

export default EisenhowerMatrix;
