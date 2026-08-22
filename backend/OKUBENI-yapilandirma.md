# Firebase yapılandırması kökte

`firebase.json` ve `.firebaserc` **depo kökünde**.

Firebase Hosting, `public` dizininin proje kökünün dışında olmasına izin
vermiyor. Yapılandırma `backend/` içindeyken `"public": "../frontend"` yazmak
gerekiyordu ve dağıtım şu hatayla düşüyordu:

    Error: ../frontend is outside of project directory

Yollar artık kök göreli: `frontend`, `backend/functions`,
`backend/firestore.rules`.

Komutlar depo kökünden çalıştırılır:

```bash
firebase deploy --only hosting,functions
firebase emulators:start --only functions,firestore,hosting
```
