# Заняття 6. Pod-и Kubernetes

**Формат:** групове, 2 аудиторні години. **Самостійна робота:** 4 години.

## Мета

Навчитися описувати Pod у YAML, читати його стан і події, розрізняти контейнерні стани та розуміти, як Kubernetes виявляє проблеми.

## Навчальні питання

1. Pod як спільна одиниця планування: мережевий простір і спільні томи.
2. Маніфест Pod: `apiVersion`, `kind`, `metadata`, `spec`.
3. Стани Pod та контейнера, `kubectl get`, `describe`, `logs`, `exec`.
4. `restartPolicy`, readiness/liveness probes і ресурси контейнера.
5. Відмінність одноразового Pod від Pod-а, створеного контролером.

## Приклад маніфесту

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  labels:
    app: web-demo
spec:
  containers:
    - name: web
      image: nginx:stable
      ports:
        - containerPort: 80
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          memory: 128Mi
```

Відступи є частиною структури YAML. `containerPort` документує порт контейнера, але сам по собі не публікує його назовні. У реальному середовищі викладач має перевірити, що вказаний образ доступний і політики кластера дозволяють ці ресурси.

## Діагностика

```bash
kubectl apply -f pod.yaml
kubectl get pod web-demo -o wide
kubectl describe pod web-demo
kubectl logs web-demo
kubectl delete -f pod.yaml
```

Обговорити `Pending` (наприклад, немає ресурсів або не підходить вузол), `ImagePullBackOff` (образ не завантажується), `CrashLoopBackOff` (процес повторно завершується). Перший крок — `describe` та події, а не випадкове видалення ресурсів.

## Самостійна робота: управління Pod-ами

Створити маніфест одного Pod-а для узгодженого вебобразу, додати label і resource requests. У нотатках вказати, якими командами перевірити label, журнали та причину помилки запуску. Пояснити, чому прямий Pod не є надійною заміною Deployment.

## Контроль засвоєння

Курсант знаходить у маніфесті ім'я, образ і label; за `describe` пояснює різницю між станом Pod та причиною помилки контейнера.
