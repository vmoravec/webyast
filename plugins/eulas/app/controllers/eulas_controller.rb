# = Eula controller
# Serves licences and handles notices about acceptations.
class EulasController < ApplicationController

  before_filter :login_required

  def index
    @licenses = License.find_all
     respond_to do |format|
       format.html
       format.xml { render :xml => @licenses.to_xml }
       format.json{ render :json=> @licenses.to_json}
     end
   end

  def show
    raise InvalidParameters.new ({:id => 'MISSING'}) if params[:id].nil?
    @id      = params[:id].to_i
    @license = License.find @id
    render ErrorResult.error(404, 1, "License not found") and return if @license.nil?
    @license.load_text params[:lang] unless params[:lang].nil?
    logger.debug @license.inspect
    respond_to do |format|
      format.html
      format.xml { render :xml => @license.to_xml }
      format.json{ render :json=> @license.to_json}
    end
  end

  def update
    raise InvalidParameters.new ({:id => 'MISSING'}) if params[:id].nil?
    @license = License.find params[:id]
    render ErrorResult.error(404, 1, "License not found") and return if @license.nil?
    @license.accept = params[:eula][:accept]
    @license.save
    render :show
  end

end