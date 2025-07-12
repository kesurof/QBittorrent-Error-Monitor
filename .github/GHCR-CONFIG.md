# Configuration pour GitHub Container Registry

## Visibilité du package

Pour s'assurer que l'image Docker soit visible publiquement sur GHCR :

1. **Aller sur GitHub** → Votre profil → Packages
2. **Trouver** `qbittorrent-monitor`
3. **Cliquer** sur Package settings
4. **Changer** la visibilité de "Private" à "Public"
5. **Confirmer** le changement

## URL publique

Une fois configuré, l'image sera accessible publiquement à :
```
ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
```

## Tags disponibles

- `latest` - Dernière version stable
- `main` - Build de la branche principale  
- `sha-XXXXXXX` - Build spécifique par commit SHA

## Commandes Docker

```bash
# Pull de l'image
docker pull ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest

# Vérifier les tags disponibles
docker images ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor

# Informations sur l'image
docker inspect ghcr.io/kesurof/qbittorrent-error-monitor/qbittorrent-monitor:latest
```
