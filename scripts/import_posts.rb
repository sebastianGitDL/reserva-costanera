##### 
# MEJORAR:
#   1. Sacar los border="1" del content de los posts, asi las tablas no se muestran con un borde negro horrible.
#      que no esta en wordpress. 
#   2. Para que la Home page se viera parecido/igual que en wordpress tuve que alinearlo manualmente al centro.
#      desde el Admin.
#   3. Como resolver tema de titulos en 'blanco' debido a translations? Le ponemos el mismo titulo en ingles.. esta ok?
#   4. Revisar porque swallow no tiene imagen.
#     http://www.reservacostanera.com.ar/las-aves/elenco-2/golondrina-rabadilla-canela-petrochelidon-pyrrhonota/


Cama::Post.delete_all


##########################################
# Establishing connection
##########################################
ActiveRecord::Base.configurations["wordpress"] = { 
  adapter: "mysql2",
  database: "wordpress_db",
  host:"127.0.0.1",
  username: "root",
  password: "" 
}

class WordpressPost < ActiveRecord::Base
  self.table_name = "wp_posts" 
end

WordpressPost.establish_connection(ActiveRecord::Base.configurations['wordpress'])

##########################################
# Utils
##########################################
def clean_text(text)
  # Fix new lines
  text.gsub!(/\r\n/, "</p>\r\n<p>")
  text.gsub!(/\n/, "</p>\n<p>")
  text.gsub!(/\r/, "</p>\r<p>")
  # Fix transalations
  if text.include? '[:en]'
    if text.include? '[:es]'
      if text.index(':en') > text.index(':es')
        text.gsub!('[:es]', '<!--:es-->')
        text.gsub!('[:en]', '<!--:--><!--:en-->')
      else
        text.gsub!('[:en]', '<!--:en-->')
        text.gsub!('[:es]', '<!--:--><!--:es-->')
      end
    else
      text.gsub!('[:en]', '<!--:en-->')
    end
  else
    text.gsub!('[:es]', '<!--:es-->')
  end
  text.gsub!('[:]','<!--:-->')
  text
end

def create_post(wordpress_post)
  cama_post                   = Cama::Post.new
  cama_post.title             = clean_text(wordpress_post.post_title)
  cama_post.content           = clean_text(wordpress_post.post_content)
  cama_post.content_filtered  = clean_text(Nokogiri::HTML(wordpress_post.post_content).text)
  cama_post.slug              = (wordpress_post.post_name.present? ? wordpress_post.post_name : Nokogiri::HTML(wordpress_post.post_title).text.parameterize)
  cama_post.created_at        = wordpress_post.post_date
  cama_post.status            = 'published'
  cama_post.visibility        = 'public'
  cama_post.post_class        = 'Post'
  cama_post.taxonomy_id       = wordpress_post.post_type == 'post' ? 2 : 7 
  cama_post.user_id           = @cora_user.id
  cama_post.wp_post_id        = wordpress_post.id
  if wordpress_post.post_parent
    cama_post_parent = Cama::Post.find_by wp_post_id: wordpress_post.post_parent
    if cama_post_parent
      cama_post.post_parent = cama_post_parent.id
    else
      @errors.write "#{wordpress_post.id}, NO PARENT FOUND\n"
    end
  end
  unless cama_post.save
    @errors.write "#{wordpress_post.id},#{cama_post.errors}\n"
  end
end

##########################################
# 1- Creando usuario de Cora
##########################################
cora_user                   = Cama::User.new
cora_user.username          = 'cora.rimoldi'
cora_user.role              = 'editor'
cora_user.email             = 'corarimoldi@gmail.com'
cora_user.first_name        = 'Cora'
cora_user.last_name         = 'Rimoldi'
cora_user.password          = 'cora01'
cora_user.save

##########################################
# 2 - Importando Parent Posts and Pages
##########################################
@cora_user ||= Cama::User.find_by email: 'corarimoldi@gmail.com'
@errors   = File.open('tmp/parent_post_import_errors.csv', 'wb')
WordpressPost.where(post_type: ['post', 'page'], post_parent: 0).each do |wordpress_post| 
  create_post(wordpress_post)
end
@errors.close

errors = []
Cama::Post.all.each do |cama_post|
  wp_post          = WordpressPost.find_by(ID: cama_post.wp_post_id)
  if wp_post and wp_post.post_parent != 0
    cama_post_parent      = Cama::Post.find_by(wp_post_id: wp_post.post_parent)
    if cama_post_parent
      cama_post.post_parent = cama_post_parent.id
      cama_post.save
    else
      errors << {cama_post.id => 'No parent imported'}
    end
  end
end


##########################################
########## TODOs if necessary
##########################################
# import image (posts del tipo attachment)
# Camaleon CMS los trata como MEDIA... 
#     Vale la pena importarlos o los vamos a subir a otro lado?
#     De eso dependera como actualizamos las URLs en los posts supongo.
# 'http://www.reservacostanera.com.ar/wp-content/uploads/2010/05/elenco-550x138.jpg' 
image_url       = content.match(/http[a-z0-9\:\/\.\-]+\.(jpg|gif|png)/)
raw_image_name  = image_url.split('/').last
image_name      = image.gsub(/\-[0-9]{1,5}x[0-9]{1,5}/,'') #remover el tamaño y quedarse con el original. De elenco-550x138.jpg -> elenco.jpg
File.open('tmp/image_name', 'wb') do |file|
  fo.write open("http://www.reservacostanera.com.ar/wp-content/uploads/2010/05/elenco-550x138.jpg").read 
end




