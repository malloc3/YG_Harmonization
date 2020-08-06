# By: Eriberto Lopez
# elopez3@uw.edu


needs "Yeast Display/YeastDisplayHelper"
needs "Tissue Culture Libs/CollectionDisplay"
needs 'Standard Libs/AssociationManagement'

needs "YG_Harmonization/Upload_PlateReader_Data"

# needs "YG_Harmonization/BiotekPlateReaderCalibration"

module PlateReaderMethods
    
    include YeastDisplayHelper
    include CollectionDisplay
    include Upload_PlateReader_Data
    # include BiotekPlateReaderCalibration
    include AssociationManagement
    
    SAVING_DIRECTORY = "_UWBIOFAB"
    # Experimental Default volume
    DEFAULT_VOLUME = { qty: 300, units: 'µl' }
    PLT_READER_LOC = "A10.530"
    PLT_READER_TYPE = 'Biotek Synergy HT'
    # Plate Reader Calibration
    CAL_TEMPLATE_FILENAME = "calibration_template_v1"
    CAL_MEASUREMENTS = ['cal_od', 'cal_gfp']

    # Directs technician to set up biotek plate reader software
    #
    # @params collection [collection obj] the collection that is being measured
    # @params template_filename [string] the name of the biotek protcol/measurement template
    def set_up_plate_reader(collection, template_filename)
        if template_filename.include? 'calibration_template'
            experiment_filename = "experiment_calibration_plate_#{todays_date}"
        else
            experiment_filename = "experiment_#{collection.id}_#{todays_date}"
        end
        # Open Biotek software
        # Set up plate reader workspace and taking measurements
        # select new exp and save
        img1 = "Actions/Yeast_Gates/plateReaderImages/open_biotek.PNG"
        img2 = "Actions/Yeast_Gates/plateReaderImages/begin_plate_reader.PNG"
        
        show do
            title "Setting Up Plate Reader Workspace"
            separator
            note "<b>The next steps should be done on the plate reader computer</b>."
            note "<b>1.</b> Open BioTek Gen5 software by clicking the icon shown below."
            image img1
            note "<b>2.</b> Under <b>'Create a New Item'</b> click <b>'Experiment'</b> "
            # select template
            note "<b>3.</b> From the list select: <b>#{template_filename}</b>"
            note "<b>4.</b> Click Read Plate icon shown below"
            image img2
            note "<b>5.</b> Click <b>'READ'</b> on the pop-up window."
            bullet "Name experiment file: <b>#{experiment_filename}</b>"
            bullet "<b>Save</b> it under the <b>#{SAVING_DIRECTORY}</b> folder."
            note "<b>6.</b> Load plate and click <b>'OK'</b>"
        end

        # show do
        #     title "Setting Up Plate Reader Workspace"
            
        #     note "Take 96 well plate to the plate reader computer, under cabinet <b>#{PLT_READER_LOC}</b>."
        #     note "Open BioTek Gen5 software by clicking the icon shown below."
        #     image img1
        #     note "Under 'Create a New Item' click <b>'Experiment'</b> "
        #     # select template
        #     note "From the list select <b>#{template_filename}</b>"
        #     note "Next, click Read Plate icon shown below and click <b>'READ'</b> on the pop-up window."
        #     image img2
        #     note "Name experiment file: <b>#{experiment_filename}</b>"
        #     note "Finally, save it under the <b>#{SAVING_DIRECTORY}</b> folder."
        #     note "Load plate and click <b>'OK'</b>"
        # end
    end
        
    
    def add_blanks(volume={}, media)
        volume = DEFAULT_VOLUME unless volume.present?
        
        show do
            title "Add Blanks to Plate"
            
            note "Prior to our measurement, we must add a blank to get a true OD reading."
            check "Fill the last three wells of the 96 Well plate <b>H10, H11, H12</b> with #{qty_display(volume)} of <b>#{media}</b> liquid media."
        end
    end
    
    def load_plate
        show do
            title "Load Plate Reader"
            
            note "Load plate on to the plate reader and click <b>'OK'</b>"
        end
    end
    
    # Exports data from plate reader (BioTek Gen 5)
    #
    # @params collection [collection obj] collection that is being measured
    # @params timepoint [integer] what hour into the experiment is this data being collected
    # @params method [string] what is being measured on the plate reader can also be gfp
    # @return filename [string] filename generated with information for downstream processing
    def export_data(collection, timepoint, method='od')
        if method.include? 'cal'
            filename = "jid_#{jid}_item_#{collection.id}_#{todays_date}_#{method}"
        else
            filename = "jid_#{jid}_item_#{collection.id}_#{timepoint}hr_#{todays_date}_#{method}"
        end
        
        img1 = "Actions/Yeast_Gates/plateReaderImages/exporting_data_new.GIF"
        img2 = "Actions/Yeast_Gates/plateReaderImages/excel_export_button_new.png"
        img3 = "Actions/Yeast_Gates/plateReaderImages/saving_export_csv_new.png"
        
        case method
        when 'od'
            dtype = 'Blank Read 1:600'
            desc = 'Optical Density'
        when 'gfp'
            dtype = 'Blank Read 2:485/20,516/20'
            desc = 'Fluorescence'
        when 'cal_od'
            dtype = 'Read 1:600'
            desc = 'Calibration Optical Density'
        when 'cal_gfp'
            dtype = 'Read 2:485/20,516/20'
            desc = 'Calibration Fluorescence'
        else
            dtype = ''
        end
        
        # Exporting single file (csv)
        show do
            title "Export #{desc} Measurements from Plate Reader"
            warning "Make sure that no other Excel sheets are open before exporting!"
            separator
            image img1
            bullet "Select the <b>'Statistics'</b> tab"
            bullet "Select Data: <b>#{dtype}</b>"
            separator
            note "Next, click the Excel sheet export button. <b>The sheet will appear on the menu bar below</b>."
            image img2
            warning "Make sure to save file as a .CSV file!"
            note "Go to sheet and <b>'Save as'</b> ==> <b>#{filename}</b> under the <b>#{SAVING_DIRECTORY}</b> folder."
            image img3
        end

        # show do
        #     title "Export #{desc} Measurements from Plate Reader"
            
        #     warning "Make sure that no other Excel sheets are open before exporting!"
        #     separator
        #     note "After measurements have been taken, be sure to select the <b>'Statistics'</b> tab"
        #     note "Select Data: <b>#{dtype}</b>"
        #     image img1
        #     note "Next, click the Excel sheet export button. The sheet will appear on the menu bar below."
        #     image img2
        #     note "Go to sheet and 'Save as' <b>#{filename}</b> under the <b>#{SAVING_DIRECTORY}</b> folder."
        #     warning "Make sure to save file as a .CSV file!"
        #     image img3
        # end
        
        return filename
    end
    
    def todays_date
        DateTime.now.strftime("%m%d%Y")
    end
    
    # Give an introduction to the sync by OD protocol
    #
    # @param wavelength [integer] the type of light measured, 0 to 900
    def intro_sync_OD(wavelength)
        show do
            title "Sychronization of Cultures by OD"
            
            note "In this protocol you will be measuring the cell concentration of cultures by Optical Density."
            note "Then we will normalize all cultures to a similar cellular concentration to begin our growth experiment."
            note "This allows researchers to observe discrepencies in growth rates of different strains and allows us to compare conditions."
            note "<b>1.</b> Setup Plate Reader (Biotek) & measure OD#{wavelength}."
            note "<b>2.</b> Take a calculated volume from each well and dilute into a 96 Deep Well Plate."
        end
    end
    
    # Associates the actual ODs calculated from the well OD and the ave culture volume diluted into the final vol
    #
    # @params out_coll [collection obj] output collection that the od_mat will be associated to 
    # @params od_mat [2-D Array] matrix containing ODs of the output collection
    def associate_true_ods_item(out_coll,od_mat)
        timepoint = 0 # timepoint now at t = 0 since we have diluted our cultures to the necessary starting ODs
        k = 'optical_density'
        method = 'od'
        od_hsh = Hash.new(0)
        od_hsh["#{timepoint}_hr_#{method}"] = od_mat
        Item.find(out_coll.id).associate(k, od_hsh)
    end
    # # This function directs tech to pre-fill deep well plate with required media
    # #
    # # @params out_coll [collection obj] the output collection object
    # # @params type_of_media [string] describes the type of media to be used in the experiment
    # # @params media_vol_mat [2-D Array] is a matrix of the media volume per well in ul 
    # def aliquot_media(out_coll, media_vol_mat, media)
    #     # Direct tech to fill output plate with media
    #     tot_media_vol = 0
    #     media_vol_mat.flatten.each {|vol| tot_media_vol += vol}
        
    #     # Where controls are to be placed in the experimental plate
    #     gfp_input_cult_coord = 'H9'
    #     wt_no_stain_coord = 'H7'
    #     wt_stain_coord = 'H8'
        
    #     rc_list = out_coll.get_non_empty
    #     rc_list.push(find_rc_from_alpha_coord(alpha_coord=gfp_input_cult_coord).first)
    #     rc_list.push(find_rc_from_alpha_coord(alpha_coord=wt_no_stain_coord).first)
    #     rc_list.push(find_rc_from_alpha_coord(alpha_coord=wt_stain_coord).first)
    #     log_info 'rc_list', rc_list
    #     show do
    #         title "Filling New 96 Deep Well Plate #{out_coll}"
            
    #         note "For this step you will need:"
    #         check "96 Well Deep U-bottom Plate and label with <b>#{out_coll.id}</b>"
    #         check "Multichannel Reservoir"
    #         check "Breathable AeraSeal Plate Cover"
    #         check "<b>#{((tot_media_vol/1000) + 1).round(1)} mLs</b> of <b>#{media}</b> liquid growth media."
    #     end
    #     show do
    #         title "Filling 96 Deep Well Plate #{out_coll}"
    #         note "Follow the table bellow to aliquot the appropriate amount of <b>#{media}</b> media to the respective well:"
    #         table highlight_rc(out_coll, rc_list) { |r, c| "#{(media_vol_mat[r][c]).round(1)} µl" }
    #     end
    # end
    
# -------------------------------------------------PlateReaderControl------------------------------------------------------------------#
    # def calibration_plate_chk()
    #     # is plate made already?
    #     check_cal_plate = show do
    #         title "Calibrating the #{PLT_READER_TYPE} Plate Reader"
    #         separator
    #         select [ "Yes", "No"], var: "cal_plate", label: "Is there a calibration plate that is less than 2 weeks old? If not, select 'No' and proceed to the next step."
    #         # note "If yes, take the calibration plate and place on the plate shaker in the 30°C incubator for 5 mins."
    #     end
    #     return (check_cal_plate[:cal_plate] == "No" ? false : true)
    # end
    
    # # Creates a calibration plate for the plate reader with a flourescence dye and a optical density reagent
    # #
    # # @params flour [string] 
    # # @params ludox [string]
    # # @params collection [collection obj] container of plate reader cal solutions
    # def create_cal_plate(cal_coll)
    #     flour_samp = Sample.find_by_name("Fluorescein Sodium Salt" )
    #     ludox_samp = Sample.find_by_name("LUDOX Stock")
        
    #     # Items and materials required for calibration plate
    #     flour_item = find(:item, { sample: { name: flour_samp.name }, object_type: { name: "1mM Fluorescein Stock" } } ).first
    #     ludox_item = find(:item, { sample: { name: ludox_samp.name }, object_type: { name: "1X LUDOX Aliquot" } } ).first
    #     cal_items = [flour_item, ludox_item]
    #     take cal_items, interactive: true
    #     h2o_type = "Nuclease-free water" # Change in Production Aq to Mol grade H2O
    #     h2o_samp = Sample.find_by_name(h2o_type) 
    #     cal_plt_mats = {'1X PBS'=>'Bench', 'Mol. Grade H2O'=>'Media Bay', '96 Well Flat Bottom (black)'=>'Bench'}
        
    #     show do
    #         title "Creating a New Calibration Plate"
    #         separator
    #         note "<b>Gather the following:</b>"
    #         cal_plt_mats.each {|mat, loc| check "#{mat} at #{loc}"}
    #     end
        
    #     show do
    #         title "Creating a New Calibration Plate"
    #         separator
    #         note "Vortex 1mM Fluorescein Stock and make sure there are no precipitates."
    #         check "In a fresh 1.5mL Eppendorf tube, dilute 50µl of 1mM Fluorescein Stock into 950µl of 1X PBS - Final Concentration [50µM]"
    #         note "Make sure to vortex."
    #     end
        
    #     dims = cal_coll.dimensions
    #     # log_info 'dims', dims
    #     rows = dims[0]
    #     cols = dims[1]
    #     new_coll_mat = Array.new(rows) { Array.new(cols) { -1 } }
    #     rows.times do |r|
    #       cols.times do |c|
    #             if r < 4
    #               new_coll_mat[r][c] = flour_samp.id 
    #             elsif r == 4
    #               new_coll_mat[r][c] = ludox_samp.id
    #             elsif r == 5
    #                 new_coll_mat[r][c] = h2o_samp.id
    #             end
    #         end
    #     end
    #     cal_plate = cal_coll
    #     cal_plate.matrix = new_coll_mat
    #     cal_plate.save
    #     # log_info 'new_coll_mat', new_coll_mat
    #     # log_info 'cal_plate matrix', cal_plate.matrix
        
    #     pbs_wells = cal_plate.select {|well| well == flour_samp.id}.select {|r, c| c != 0}
        
    #     # direct tech to fill new calibration plate
    #     show do
    #         title "Creating a New Calibration Plate"
    #         separator
    #         note "You will need <b>#{(pbs_wells.length * 0.1) + 0.1}mL</b> of 1X PBS for the next step."
    #         note "Follow the table below to dispense 1X PBS in the appropriate wells:"
    #         table highlight_rc(cal_plate, pbs_wells) {|r,c| "100µl"}
    #     end
        
    #     flour_serial_image = "Actions/Yeast_Gates/plateReaderImages/flour_serial_dilution.png"
    #     show do
    #         title "Serial Dilution of Flourescein"
    #         separator
    #         note "From the 50µM Fluorescein solution, dispense <b>200µl</b> in wells <b>A1, B1, C1, D1</b>"
    #         note "Following the image below, transfer <b>100µl</b> of 50µM Fluorescein solution in Column 1 to Column 2"
    #         note "Resuspend by pipetting up and down 3X"
    #         note "Repeat until column 11 and discard the remaining <b>100µl</b>."
    #         image flour_serial_image
    #     end
        
    #     ludox_wells = cal_plate.select {|well| well == ludox_samp.id}
        
    #     show do
    #         title "Creating a New Calibration Plate"
    #         separator
    #         note "Follow the table below to dispense #{ludox_samp.name} into the appropriate wells."
    #         table highlight_rc(cal_plate, ludox_wells) {|r,c| ludox_vol(r, c)}
    #     end
        
    #     h2o_wells = cal_plate.select {|well| well == h2o_samp.id}
        
    #     show do
    #         title "Creating a New Calibration Plate"
    #         separator
    #         note "Follow the table below to dispense #{h2o_type} into the appropriate wells."
    #         table highlight_rc(cal_plate, h2o_wells) {|r,c| ludox_vol(r, c)}
    #     end
    #     # Assocaite todays_date with item
    #     Item.find(cal_plate.id).associate('date_created', todays_date)
    #     release cal_items, interactive: true
    #     return cal_plate
    # end
    
    # def ludox_vol(row, col)
    #     if col < 4
    #         return "100µl"
    #     elsif col.between?(4, 7)
    #         return "200µl"
    #     else col.between?(7, 11)
    #         return "300µl"
    #     end
    # end
    
    # # This function directs tech to measure calibration plate on plate reader and export data; it also associates data from plate reader
    # #
    # # @params cal_plates [Array] an array of item objects
    # #
    # def measure_cal_plate(cal_plates)
    #     cal_plate = cal_plates.first
    #     # measure on plate reader 
    #     set_up_plate_reader(cal_plate, CAL_TEMPLATE_FILENAME)
        
    #     # Export a file for each measurement - Can the plate Reader export in xml?
    #     CAL_MEASUREMENTS.each do |method|
            
    #         timepoint = nil # Is nil since it is not being measured along with this experiment
    #         filename = export_data(cal_plate, timepoint, method=method)
            
    #         # Show block upload button and retrieval of file uploaded
    #         up_show, up_sym = upload_show(filename)
    #         if (up_show[up_sym].nil?)
    #             show {warning "No upload found for calibration measurement. Try again!!!"}
    #             up_show, up_sym = upload_show(filename)
    #         else
    #             upload = find_upload_from_show(up_show, up_sym)
    #             key = "#{todays_date}_#{method}"
    #             # Need to associate data to all plans that are batched in job
    #             associate_to_plan(upload, key)
                
    #             # Associates upload to calibration plate and plan
    #             cal_plates.each do |cal_plate|
    #                 associate_to_item(cal_plate, key, upload)
    #                 # Associates data hash of measurements to item/collection - extract info from plate reader upload and associate with item
    #                 associate_PlateReader_Data(upload, cal_plate, method, timepoint)
    #             end
    #         end
    #     end
    #     cal_plates.shift.location = '4°C Fridge'
    #     cal_plates.each {|plt| plt.mark_as_deleted}
    # end
#-------------------------------------------------PlateReaderControl------------------------------------------------------------------#

end # module