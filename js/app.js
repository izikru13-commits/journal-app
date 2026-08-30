// Zikkit (זיקית) — app root.
function App() {
  const [profile, setProfile] = React.useState(() => getProfile());
  const [activeGameId, setActiveGameId] = React.useState(null);
  const activeGame = GAMES.find((g) => g.id === activeGameId);

  return (
    <AppShell profile={profile} activeGame={activeGame} onHome={() => setActiveGameId(null)}>
      {activeGame ? (
        <activeGame.component profile={profile} onProfileUpdate={setProfile} />
      ) : (
        <GameMenu games={GAMES} onSelect={setActiveGameId} />
      )}
    </AppShell>
  );
}

ReactDOM.render(<App />, document.getElementById("root"));
