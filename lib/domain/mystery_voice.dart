// First-person presentation of existing sourced clues; factual qualifiers preserved.
const mysteryVoices = <String, String>{
  'Le mâle adulte est noir avec un bec jaune vif. La femelle est brun foncé, avec un dessous un peu plus clair et marbré.':
      'Si je suis un mâle adulte, je suis noir avec un bec jaune vif. Ma femelle est brun foncé, avec un dessous un peu plus clair et marbré.',
  'Regarde ses joues blanches et les zones bleues, jaunes et vert olive de son plumage. Un bandeau sombre traverse le côté de la tête.':
      'Mes joues sont blanches et mon plumage mêle du bleu, du jaune et du vert olive. Un bandeau sombre traverse le côté de ma tête.',
  'Cherche l’orange vif sur la face, la gorge et la poitrine de l’adulte. Le dos est brun-olive et le ventre clair.':
      'Adulte, ma face, ma gorge et ma poitrine sont orange vif. Mon dos est brun-olive et mon ventre est clair.',
  'Chez l’adulte, cherche les taches blanches du cou et des ailes. Son corps gris-bleu contraste avec une poitrine aux tons vineux.':
      'Adulte, je porte des taches blanches sur le cou et les ailes. Mon corps est gris-bleu et ma poitrine a des tons vineux.',
  'Observe son plumage beige clair et le demi-collier noir derrière le cou. Sa longue queue présente du blanc.':
      'Mon plumage est beige clair et je porte un demi-collier noir derrière le cou. Il y a du blanc sur ma longue queue.',
  'Sa queue dessine une fourche prolongée par deux longs filets. Regarde aussi sa gorge brun-roux et son dos aux reflets bleus.':
      'Ma queue forme une fourche prolongée par deux longs filets. Ma gorge est brun-roux et mon dos a des reflets bleus.',
  'Son dos bleu-noir contraste avec le blanc du ventre et du croupion. Sa queue est légèrement fourchue.':
      'Mon dos est bleu-noir, mais mon ventre et mon croupion sont blancs. Ma queue est légèrement fourchue.',
  'Observe son gros bec et sa queue en forme de coin. Son plumage noir brille, et les plumes de sa gorge semblent parfois ébouriffées.':
      'J’ai un gros bec et une queue en forme de coin. Mon plumage noir brille et les plumes de ma gorge semblent parfois ébouriffées.',
  'Le dos et le ventre sont gris, tandis que la tête, les ailes et la queue sont noirs. Ce contraste la distingue de la Corneille noire.':
      'Mon dos et mon ventre sont gris, tandis que ma tête, mes ailes et ma queue sont noirs. Ce contraste me distingue de la Corneille noire.',
  'Cherche un plumage noir et blanc très contrasté, avec une longue queue aux plumes de longueurs différentes.':
      'Mon plumage est noir et blanc, très contrasté. Ma longue queue possède des plumes de longueurs différentes.',
  'Sur ses ailes, remarque la petite zone bleue ! Son plumage rosé, sa moustache noire et son croupion blanc donnent d’autres indices.':
      'Je porte une petite zone bleue sur mes ailes ! Mon plumage est rosé, ma moustache noire et mon croupion blanc.',
  'Repère les joues blanches sur la tête noire, puis la bande sombre qui descend sur la poitrine jaune. Elle est souvent plus large chez le mâle.':
      'Mes joues blanches ressortent sur ma tête noire. Une bande sombre descend sur ma poitrine jaune ; elle est souvent plus large chez le mâle.',
  'Ses joues et une tache sur sa nuque sont blanches, autour d’une tête largement noire. Son dos est gris.':
      'Mes joues et une tache sur ma nuque sont blanches, autour de ma tête largement noire. Mon dos est gris.',
  'Sa queue dépasse la longueur de son corps ! Son plumage associe du blanc, du noir et du rose.':
      'Ma queue est plus longue que mon corps ! Mon plumage mêle du blanc, du noir et du rose.',
  'Regarde son bandeau noir, son dos gris-bleu et son dessous roussâtre. Elle se déplace sur les troncs dans toutes les positions.':
      'Je porte un bandeau noir, un dos gris-bleu et un dessous roussâtre. Je me déplace sur les troncs dans toutes les positions.',
  'Ce petit oiseau brun-roux porte souvent sa courte queue relevée. De fines barres sombres marquent sa queue, ses ailes et ses flancs.':
      'Je suis un petit oiseau brun-roux et je relève souvent ma courte queue. De fines barres sombres marquent ma queue, mes ailes et mes flancs.',
  'Regarde sa calotte : elle est noire chez le mâle adulte, mais brune chez la femelle et chez les jeunes. Le reste du plumage est discret, gris et brun.':
      'Ma calotte est noire si je suis un mâle adulte, mais brune si je suis une femelle ou un jeune. Le reste de mon plumage est discret, gris et brun.',
  'Sa queue courte et ses ailes pointues dessinent une silhouette compacte. Son plumage sombre montre des reflets colorés et davantage de points clairs en hiver.':
      'Ma queue courte et mes ailes pointues me donnent une silhouette compacte. Mon plumage sombre a des reflets colorés et davantage de points clairs en hiver.',
  'Le mâle porte une calotte grise et une bavette noire. La femelle a un dessus brun rayé, plus discret.':
      'Si je suis un mâle, ma calotte est grise et ma bavette noire. Ma femelle a un dessus brun rayé, plus discret.',
  'Repère sa tête coiffée de noir et son croupion blanc. La poitrine du mâle est rose vif ; celle de la femelle est gris-brun.':
      'Ma tête est coiffée de noir et mon croupion est blanc. Ma poitrine est rose vif chez le mâle et gris-brun chez la femelle.',
  'Les marques blanches des ailes sont de bons indices. Le mâle a la poitrine et les joues couleur brique ; femelles et jeunes sont plus brun-olive.':
      'Je porte des marques blanches sur les ailes. Chez le mâle, ma poitrine et mes joues sont couleur brique ; les femelles et les jeunes sont plus brun-olive.',
  'Chez l’adulte, cherche le rouge du visage et la bande jaune de l’aile. Attention : les jeunes n’ont pas encore le masque rouge.':
      'Adulte, je porte du rouge sur le visage et une bande jaune sur l’aile. Mes jeunes n’ont pas encore ce masque rouge.',
  'En vol, observe sa queue rousse très échancrée et ses ailes coudées. Sa tête est claire et rayée, sur un corps brun-roux.':
      'En vol, ma queue rousse est très échancrée et mes ailes sont coudées. Ma tête est claire et rayée, et mon corps brun-roux.',
  'En chasse, il peut rester presque immobile dans les airs. Observe ses ailes pointues et sa longue queue ; chez le mâle, la tête est gris-bleu.':
      'Quand je chasse, je peux rester presque immobile dans les airs. Mes ailes sont pointues et ma queue longue ; chez le mâle, ma tête est gris-bleu.',
  'Cherche du rouge sur le bec et sur le front. Sous sa queue, le blanc contraste avec le noir.':
      'Je porte du rouge sur le bec et sur le front. Sous ma queue, le blanc contraste avec le noir.',
  'Sur l’eau, cherche un oiseau sombre avec un bec et une plaque frontale blancs. Sur terre, ses très grandes pattes sont un autre indice.':
      'Je suis un oiseau sombre avec un bec et une plaque frontale blancs. Sur terre, mes très grandes pattes peuvent t’aider à me reconnaître.',
  'En été, la tête porte un capuchon brun foncé. Le corps est surtout blanc, le dos gris, et les pattes ainsi que le bec sont rouges.':
      'En été, je porte un capuchon brun foncé sur la tête. Mon corps est surtout blanc, mon dos gris, et mes pattes et mon bec sont rouges.',
  'Observe le contraste entre le dos bleu-vert et le ventre orangé. Il a une grosse tête, un long bec et une petite queue.':
      'Mon dos est bleu-vert et mon ventre orangé. J’ai une grosse tête, un long bec et une petite queue.',
  'Son plumage vert, son croupion jaune et sa calotte rouge sont de bons indices. La moustache est rouge chez le mâle, noire chez la femelle.':
      'Mon plumage est vert, mon croupion jaune et ma calotte rouge. Ma moustache est rouge chez le mâle et noire chez la femelle.',
  'Son plumage noir et blanc porte du rouge sous la queue. Le mâle a aussi du rouge à la nuque ; le jeune en porte sur la calotte.':
      'Mon plumage noir et blanc porte du rouge sous la queue. Chez le mâle, ma nuque est aussi rouge ; chez le jeune, c’est ma calotte.',
  'Blanc et noir, longues pattes rouges et bec rouge : voilà de bons indices ! En vol, son cou et ses pattes restent étendus.':
      'Je suis blanc et noir, avec de longues pattes rouges et un bec rouge. En vol, je garde mon cou et mes pattes étendus.',
  'Ce grand oiseau blanc porte un bec orange. À la base du bec se trouve une bosse noire, souvent plus développée chez le mâle.':
      'Je suis un grand oiseau blanc avec un bec orange. À la base de mon bec, une bosse noire est souvent plus développée chez le mâle.',
  'En plumage nuptial, le mâle porte une tête verte et un fin collier blanc. La femelle est brune. Leurs ailes montrent une zone bleu-violet.':
      'En plumage nuptial, le mâle de mon espèce porte une tête verte et un fin collier blanc. La femelle est brune. Nos ailes ont une zone bleu-violet.',
  'Pendant la reproduction, sa tête porte de grandes touffes rousses et sombres. Ses joues et son long cou sont blancs.':
      'Pendant la reproduction, je porte de grandes touffes rousses et sombres sur la tête. Mes joues et mon long cou sont blancs.',
  'Le mâle présente des flancs blancs contrastant avec le noir, et une petite huppe pendante. La femelle est brune ; en été, le mâle devient lui aussi plus brun.':
      'Chez le mâle, mes flancs blancs contrastent avec mon plumage noir et je porte une petite huppe pendante. La femelle est brune ; en été, le mâle devient lui aussi plus brun.',
};
