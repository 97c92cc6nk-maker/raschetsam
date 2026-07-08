# Расчет самозанятых

Веб-приложение для учета смен, недельных выплат, реквизитов, договоров, актов и ТЗ.

## Онлайн-режим

Приложение подключено к Supabase:

- Project URL: `https://mpsopvezhguzkkhvjnwy.supabase.co`
- Используется публичный publishable key для браузера.
- Данные пользователя хранятся в таблице `public.app_states`.
- Доступ ограничен Row Level Security: каждый пользователь видит только свою запись.

## Первичная настройка Supabase

1. Откройте Supabase Dashboard.
2. Перейдите в SQL Editor.
3. Выполните файл `supabase-schema.sql`.
4. В Authentication включите Email/Password.
5. После публикации на Vercel в Authentication -> URL Configuration укажите Site URL вашего сайта и добавьте его в Redirect URLs.

## Деплой на Vercel

1. Загрузите проект в GitHub.
2. В Vercel выберите Add New Project.
3. Импортируйте репозиторий.
4. Framework Preset: Other.
5. Build Command оставьте пустым.
6. Output Directory оставьте пустым или `.`.
7. Deploy.

## Как работает синхронизация

- Без входа данные сохраняются локально в браузере.
- После входа данные загружаются из Supabase.
- Если облачной копии еще нет, создается первая копия текущих локальных данных.
- После правок приложение сохраняет состояние локально и автоматически отправляет его в Supabase.

## Важная безопасность

Не публикуйте `service_role` key, secret key, пароли и приватные документы в репозитории. В браузере должен быть только publishable/anon public key.