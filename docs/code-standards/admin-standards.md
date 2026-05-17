# Admin Standards (React + Vite)

React 19 + TypeScript 5.9 + Vite 7 conventions for `wardrobe-backend/wardrobe-admin/`.

---

## Key Rules

### 1. TanStack Query for Server State

Use TanStack Query (React Query) exclusively for API data. No Redux, Zustand, or MobX.

```typescript
import { useQuery, useMutation } from '@tanstack/react-query';
import { userService } from '../services/user-service';

const UsersPage = () => {
  // Fetch users
  const { data: users, isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: userService.listUsers
  });
  
  // Mutate users
  const { mutate: promoteToAdmin, isPending } = useMutation({
    mutationFn: (userId: string) => userService.promoteToAdmin(userId),
    onSuccess: () => {
      // Invalidate users query to refetch
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
    onError: (error) => {
      message.error(error.message);
    }
  });
  
  return (
    <>
      {isLoading && <Spin />}
      {error && <Alert message={error.message} type="error" />}
      {users?.map(u => (
        <UserRow
          key={u.id}
          user={u}
          onPromote={() => promoteToAdmin(u.id)}
          loading={isPending}
        />
      ))}
    </>
  );
};
```

**Rules:**
- Use `useQuery` for reads
- Use `useMutation` for writes
- Invalidate queries on mutation success
- Handle loading + error states

### 2. React Router 7 Patterns

```typescript
// src/pages/user-detail.tsx
import { useParams, useNavigate } from 'react-router-dom';

export default function UserDetailPage() {
  const { userId } = useParams<{ userId: string }>();
  const navigate = useNavigate();
  
  const { data: user } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => userService.getUser(userId!)
  });
  
  return (
    <>
      <Button onClick={() => navigate('/users')}>Back</Button>
      <UserForm user={user} />
    </>
  );
}

// src/app.tsx (route config)
import { BrowserRouter, Routes, Route } from 'react-router-dom';

export function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="users" element={<Users />} />
          <Route path="users/:userId" element={<UserDetail />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
```

### 3. Protected Routes with AuthContext

```typescript
// src/context/auth-context.tsx
import React, { createContext, useContext } from 'react';

interface AdminUser {
  id: string;
  email: string;
  role: 'admin' | 'user';
}

interface AuthContextType {
  user: AdminUser | null;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = React.useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = React.useState(true);
  
  const login = async (email: string, password: string) => {
    const response = await authService.login(email, password);
    setUser(response.user);
  };
  
  const logout = () => {
    setUser(null);
  };
  
  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth called outside AuthProvider");
  return ctx;
}

// src/components/protected-route.tsx
function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, isLoading } = useAuth();
  
  if (isLoading) return <Spin />;
  if (!user) return <Navigate to="/login" replace />;
  if (user.role !== 'admin') return <Navigate to="/" replace />;
  
  return children;
}

// Usage in routes
<Routes>
  <Route path="/login" element={<LoginPage />} />
  <Route
    path="/dashboard"
    element={
      <ProtectedRoute>
        <Dashboard />
      </ProtectedRoute>
    }
  />
</Routes>
```

---

## Project Structure

```
wardrobe-admin/
├── src/
│   ├── pages/                # React Router pages (Dashboard, Users, etc.)
│   ├── components/           # Reusable components
│   ├── services/             # API clients (axios-based)
│   ├── context/              # React Context (AuthContext)
│   ├── types/                # TypeScript definitions
│   ├── utils/                # Helpers
│   ├── App.tsx               # Root component + route config
│   └── main.tsx              # Entry point
├── vite.config.ts            # Vite bundler config
├── wrangler.jsonc            # Cloudflare Workers config
├── worker.js                 # Cloudflare Workers entry point
├── package.json
├── tsconfig.json
├── README.md
└── index.html
```

---

## File Naming Convention

Use `kebab-case` for all TypeScript files:
- `user-detail.tsx`
- `auth-context.tsx`
- `user-service.ts`

---

## Common Patterns

### Data Table with Pagination

```typescript
const UsersTable = () => {
  const [page, setPage] = React.useState(1);
  const pageSize = 20;
  
  const { data, isLoading } = useQuery({
    queryKey: ['users', page],
    queryFn: () => userService.listUsers({ page, limit: pageSize })
  });
  
  return (
    <>
      <Table
        columns={[
          { title: 'Email', dataIndex: 'email', key: 'email' },
          { title: 'Role', dataIndex: 'role', key: 'role' },
          { title: 'Created', dataIndex: 'createdAt', key: 'createdAt' }
        ]}
        dataSource={data?.items}
        loading={isLoading}
        pagination={{
          current: page,
          total: data?.total,
          pageSize,
          onChange: (p) => setPage(p)
        }}
      />
    </>
  );
};
```

### Form with Mutation

```typescript
const UserForm = ({ user }: { user?: User }) => {
  const [form] = Form.useForm();
  const navigate = useNavigate();
  
  const { mutate: saveUser, isPending } = useMutation({
    mutationFn: (data: User) => 
      user 
        ? userService.updateUser(user.id, data)
        : userService.createUser(data),
    onSuccess: () => {
      message.success('User saved');
      navigate('/users');
      queryClient.invalidateQueries({ queryKey: ['users'] });
    },
    onError: (error) => {
      message.error(error.message);
    }
  });
  
  return (
    <Form
      form={form}
      initialValues={user}
      onFinish={(values) => saveUser(values)}
      layout="vertical"
    >
      <Form.Item label="Email" name="email" rules={[{ required: true }]}>
        <Input type="email" />
      </Form.Item>
      <Form.Item label="Role" name="role">
        <Select options={[
          { value: 'user', label: 'User' },
          { value: 'admin', label: 'Admin' }
        ]} />
      </Form.Item>
      <Button type="primary" htmlType="submit" loading={isPending}>
        Save
      </Button>
    </Form>
  );
};
```

### Modal with Confirmation

```typescript
const [isModalOpen, setIsModalOpen] = React.useState(false);
const [selectedUser, setSelectedUser] = React.useState<User | null>(null);

const { mutate: deleteUser } = useMutation({
  mutationFn: (userId: string) => userService.deleteUser(userId),
  onSuccess: () => {
    message.success('User deleted');
    setIsModalOpen(false);
    queryClient.invalidateQueries({ queryKey: ['users'] });
  }
});

return (
  <>
    <Button danger onClick={() => {
      setSelectedUser(user);
      setIsModalOpen(true);
    }}>
      Delete
    </Button>
    
    <Modal
      open={isModalOpen}
      title="Delete User"
      onOk={() => deleteUser(selectedUser!.id)}
      onCancel={() => setIsModalOpen(false)}
    >
      <p>Are you sure you want to delete {selectedUser?.email}?</p>
    </Modal>
  </>
);
```

---

## Stack & Dependencies

- **React:** 19.x (latest)
- **Vite:** 7.x (build tool)
- **TypeScript:** 5.9
- **React Router:** 7.x (client-side routing)
- **TanStack Query (React Query):** 5.x (server state)
- **Ant Design:** 6.x (UI components)
- **Tailwind CSS:** 4.x (utility CSS)
- **axios:** HTTP client

---

## Deployment

### Development

```bash
npm install
npm run dev    # Vite dev server, http://localhost:5173
```

### Production (Cloudflare)

```bash
npm run build:prod    # Build for prod backend URL
npm run deploy:prod   # Deploy via Wrangler
```

**wrangler.jsonc:** Configure API URL, environment variables

---

## Testing

```bash
npm run test          # Run Jest tests
npm run test:watch    # Watch mode
npm run coverage      # Coverage report
```

**Target:** >70% coverage for business logic

---

## Common Issues

- **Slow list rendering:** Use react-window for virtualization (1000+ items)
- **Stale data:** Always invalidate queries after mutations
- **Auth errors:** Ensure token is refreshed before expiry (7 days)
