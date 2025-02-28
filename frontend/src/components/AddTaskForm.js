import React, { useState } from 'react';
import { 
  FormLayout, 
  FormItem, 
  Input, 
  Checkbox, 
  Button, 
  Group, 
  Card,
  FormStatus
} from '@vkontakte/vkui';

const AddTaskForm = ({ onAddTask }) => {
  const [title, setTitle] = useState('');
  const [urgent, setUrgent] = useState(false);
  const [important, setImportant] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    
    if (!title.trim()) {
      setError('Пожалуйста, введите название задачи');
      return;
    }
    
    onAddTask(title, urgent, important);
    
    // Сбрасываем форму
    setTitle('');
    setUrgent(false);
    setImportant(false);
    setError('');
  };

  return (
    <Group>
      <Card mode="shadow">
        <FormLayout onSubmit={handleSubmit}>
          {error && (
            <FormStatus header="Ошибка" mode="error">
              {error}
            </FormStatus>
          )}
          
          <FormItem top="Название задачи">
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Введите название задачи"
            />
          </FormItem>
          
          <FormItem>
            <Checkbox
              checked={urgent}
              onChange={(e) => setUrgent(e.target.checked)}
            >
              Срочно
            </Checkbox>
          </FormItem>
          
          <FormItem>
            <Checkbox
              checked={important}
              onChange={(e) => setImportant(e.target.checked)}
            >
              Важно
            </Checkbox>
          </FormItem>
          
          <FormItem>
            <Button size="l" stretched type="submit">
              Добавить задачу
            </Button>
          </FormItem>
        </FormLayout>
      </Card>
    </Group>
  );
};

export default AddTaskForm;
