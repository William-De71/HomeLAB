---
title: Services
layout: default
nav_order: 4
has_children: true
---

# Services

Documentation par service. Chaque page couvre l'installation, les commandes de
gestion, les choix de configuration et le dépannage.

## Services installés

| Service | Description | Version du script |
|---|---|---|
| [Gladys Assistant]({{ site.baseurl }}/services/gladys/) | Domotique auto-hébergée (Zigbee, Z-Wave, MQTT…) | 0.0.1 |

## Modèle commun

Tous les services suivent la même structure, ce qui rend leur usage
interchangeable :

```bash
cd <NomDuService>
make install        # installation initiale
make start          # démarrer
make stop           # arrêter
make logs           # suivre les logs
make update         # mettre à jour les images Docker
make update-repo    # mettre à jour les scripts du dépôt
make clean          # supprimer les images sans tag
make uninstall      # désinstaller (données conservées)
```

{: .note }
> Les cibles disponibles peuvent varier légèrement d'un service à l'autre.
> Consultez la page du service concerné, ou ouvrez son `makefile`.

Pour ajouter un nouveau service au dépôt, voir
[Ajouter un service]({{ site.baseurl }}/contribuer/).
