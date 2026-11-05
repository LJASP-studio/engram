<!-- engram:start -->
## Kasa (engram)
Proje bilgisi `{{vault}}/` kasasında (Obsidian). Her notun tek satırlık `description:` alanı ve anlattığı kodun yerini gösteren `code:` alanı var. Kodda aramadan önce:
1. `{{vault}}/` içinde `^description:` satırlarını sorunun anahtar kelimeleriyle ara (Grep, `-A 4`: `source:` ve `code:` satırları da gelir). Çoğu soru burada biter: `code:` yollarına git.
2. Eşleşme yoksa ya da soru genişse `{{vault}}/{{hub}}.md`, sonra uygun klasörün dizinini oku (`{{vault}}/<Klasör>/<Klasör>.md`); projeleri kesen sorular için `{{vault}}/{{concepts}}/{{concepts}}.md`.
3. En fazla 3 not aç. Notlar cevap vermezse kodda ara.
İş bitince `/engram:note` ile not al. Kasa bu bilgisayarda, yerel git'te durur; uzak repo eklenmez.
<!-- engram:end -->
