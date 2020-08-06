needs 'Standard Libs/MatrixTools'
needs 'YG_Harmonization/PlateReaderMethods'
# This module is used for doing the extraction and calculations required to
# successfully calibrate the Biotek Plate reader
#
module BiotekPlateReaderCalibration
    include PlateReaderMethods
    include MatrixTools
    require 'csv'
    require 'open-uri'

    CAL_TEMPLATE_FILENAME = "calibration_template_v1"
    CAL_MEASUREMENTS = ['cal_od', 'cal_gfp']

  # Takes in a csv upload file, extracts the information on it
  # into a datamatrix object which is returned.
  # Specificly tuned to the output file of the biotek plate reader.
  #
  # @param upload [Upload]  the object which can be resolved to calibration csv
  # @return [WellMatrix]  a WellMatrix holding the measurement for each well
  def extract_measurement_matrix_from_csv(upload)
    url = upload.url
    table = []
    CSV.new(open(url)).each { |line| table.push(line) }
    dm = WellMatrix.create_empty(96, 'NA') if table.size > 25
    dm = WellMatrix.create_empty(24, 'NA') if table.size <= 25
    table.each_with_index do |row, idx|
      next if idx.zero?
      well_coord = row[2]
      next if well_coord.nil?
      measurement = row[3].to_f
      next if measurement.nil?
      dm.set(well_coord, measurement)
    end
    dm
  end

    # Returns the average OD measurement for different dilutions and well volumes.
    # The plotted result of this method can be fit to a curve
    # to be used for calibrating the plate reader. This is very specific to the
    # Eriberto's calibration of the biotek plate reader.
    #
    # @param upload [Upload]  the object whihc can be resolved to calibration csv
    # @return [Hash]  a hash containing averaged measurements for every concentration and volume tested
    def get_calibration_data_hash(upload)
        method = upload.name
        dm = extract_measurement_matrix_from_csv(upload)
        result = {}
        data_by_conc = Hash.new { |h, key| h[key] = [0, 0] }

        if method.include? 'gfp'
            show {note "#{method}"}
            starting_concentration = 50.0#uM
            # first 4 rows are serial dilutions
            for i in 0...4
              12.times do |j|
                # each column is a 2x dilution of the previous, starting at 50uM
                this_conc = starting_concentration / (2**j)
                data = data_by_conc[this_conc]
                data[0] += dm[i, j].to_f
                data[1] += 1
                data_by_conc[this_conc] = data
              end
            end
            # add serial dilution averages to result hash
            data_by_conc.each_key do |k,|
              data = data_by_conc[k]
              result[k] = data[0] / data[1]
            end
            return result
        elsif method.include? 'od'
            # row 5, 6 are lud dilutions and pure solution respectively
            for i in 4...6
                for j in 0...4
                    data_by_conc["100_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["100_#{i}"][1] += 1
                end
                for j in 4...8
                    data_by_conc["200_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["200_#{i}"][1] += 1
                end
                for j in 8...12
                    data_by_conc["300_#{i}"][0] += dm[i, j].to_f
                    data_by_conc["300_#{i}"][1] += 1
                end
            end
            # add lud averages to result hash
            for i in 1..3
              lud_avg = data_by_conc["#{i}00_4"][0] / data_by_conc["#{i}00_4"][1]
              sol_avg = data_by_conc["#{i}00_5"][0] / data_by_conc["#{i}00_5"][1]
              result["lud#{i}00"] = (lud_avg - sol_avg).round(5) # Returns blanked averages
            end
        end
        result
    end
  
  #-------------Plate ReaderCalibration------------------------------------------------------------#
    # Finds the first 
    def check_cal_plate_date()
        
        create_a_new_cal_plt = false
        calibration_plate = nil # if the plate is less than a month old use the cal plate
        
        # Look through flat bottom plates and see which one has flourescein inside
        flour_samp = Sample.find_by_name("Fluorescein Sodium Salt" )
        test_plts = find(:item,{object_type: { name: "96 Well Flat Bottom (black)" }} ).select {|i| i.location != 'deleted'}
        
        # Check to see if there is a calibration plate that is less than a month old
        test_plts.each do |item_id|
            mat = Collection.find(item_id).matrix.flatten.uniq
            if mat.include? flour_samp.id
                date_created = Item.find(item_id).get('date_created')
                
                present = todays_date()
                
                plus_month = [date_created[0..1], date_created[2..3], date_created[4..7]].map {|i| i.to_i}
                plus_month[0] = plus_month[0] + 1
                
                date_created = [date_created[0..1], date_created[2..3], date_created[4..7]].map {|i| i.to_i}
                
                today = [present[0..1], present[2..3], present[4..7]].map {|i| i.to_i}
                
                # log_info 'CALIBRATION PLATE AGE','date_created', date_created, 'plus_month', plus_month, 'todays_date', today
                
                if date_created[0] == plus_month[0] # Checking month
                    if plus_month[1] >= date_created[1] # Checking day
                        create_a_new_cal_plt = true
                        Item.find(item_id).mark_as_deleted
                    else
                        calibration_plate = item_id
                    end
                else
                    calibration_plate = item_id
                end
            end
        end
        return create_a_new_cal_plt, calibration_plate
    end


    
    
    # Creates a calibration plate for the plate reader with a Fluorescein dye and an optical density reagent
    #
    # @params flour [string] 
    # @params ludox [string]
    # @params collection [collection obj] container of plate reader cal solutions
    def create_cal_plate(cal_coll)
        flour_samp = Sample.find_by_name("Fluorescein Sodium Salt" )
        ludox_samp = Sample.find_by_name("LUDOX Stock")
        
        # Items and materials required for calibration plate
        flour_item = find(:item, { sample: { name: flour_samp.name }, object_type: { name: "1mM Fluorescein Stock" } } ).first
        ludox_item = find(:item, { sample: { name: ludox_samp.name }, object_type: { name: "1X LUDOX Aliquot" } } ).first
        cal_items = [flour_item, ludox_item]
        
        take cal_items, interactive: true
        
        h2o_type = "Nuclease-free water" # Change in Production Aq to Mol grade H2O
        h2o_samp = Sample.find_by_name(h2o_type) 
        cal_plt_mats = {'1X PBS'=>'Bench', 'Mol. Grade H2O'=>'Media Bay', '96 Well Flat Bottom (black)'=>'Bench'}
        
        show do
            title "Creating a New Calibration Plate"
            separator
            note "<b>Gather the following:</b>"
            cal_plt_mats.each {|mat, loc| check "#{mat} at #{loc}"}
        end
        
        show do
            title "Creating a New Calibration Plate"
            separator
            note "Vortex 1mM Fluorescein Stock and make sure there are no precipitates."
            check "In a fresh 1.5mL Eppendorf tube, dilute 50µl of 1mM Fluorescein Stock into 950µl of 1X PBS - Final Concentration [50µM]"
            note "Make sure to vortex."
        end
        
        dims = cal_coll.dimensions
        rows = dims[0]
        cols = dims[1]
        new_coll_mat = Array.new(rows) { Array.new(cols) { -1 } }
        rows.times do |r|
           cols.times do |c|
                if r < 4
                   new_coll_mat[r][c] = flour_samp.id 
                elsif r == 4
                   new_coll_mat[r][c] = ludox_samp.id
                elsif r == 5
                    new_coll_mat[r][c] = h2o_samp.id
                end
            end
        end
        cal_plate = cal_coll
        cal_plate.matrix = new_coll_mat
        cal_plate.save
        
        # selects wells that have flourescin sample id, then selects for the one's that are not in the first column of the collection is an array of [r,c]
        pbs_wells = cal_plate.select {|well| well == flour_samp.id}.select {|r, c| c != 0}
        
        # direct tech to fill new calibration plate
        show do
            title "Creating a New Calibration Plate"
            separator
            note "You will need <b>#{(pbs_wells.length * 0.1) + 0.1}mL</b> of 1X PBS for the next step."
            note "Follow the table below to dispense 1X PBS in the appropriate wells:"
            table highlight_rc(cal_plate, pbs_wells) {|r,c| "100µl"}
        end
        
        flour_serial_image = "Actions/Yeast_Gates/plateReaderImages/flour_serial_dilution.png"
        show do
            title "Serial Dilution of Flourescein"
            separator
            note "From the 50µM Fluorescein solution, dispense <b>200µl</b> in wells <b>A1, B1, C1, D1</b>"
            note "Following the image below, transfer <b>100µl</b> of 50µM Fluorescein solution in Column 1 to Column 2"
            note "Resuspend by pipetting up and down 3X"
            note "Repeat until column 11 and discard the remaining <b>100µl</b>."
            image flour_serial_image
        end
        
        # selects wells of a collection that have the ludox sample id, collects them as an array of [r, c]
        ludox_wells = cal_plate.select {|well| well == ludox_samp.id}
        
        show do
            title "Creating a New Calibration Plate"
            separator
            note "Follow the table below to dispense #{ludox_samp.name} into the appropriate wells."
            table highlight_rc(cal_plate, ludox_wells) {|r,c| ludox_vol(r, c)}
        end
        
        # selects wells of a collection that have the MG H2O sample id, collects them as an array of [r, c]
        h2o_wells = cal_plate.select {|well| well == h2o_samp.id}
        
        show do
            title "Creating a New Calibration Plate"
            separator
            note "Follow the table below to dispense #{h2o_type} into the appropriate wells."
            table highlight_rc(cal_plate, h2o_wells) {|r,c| ludox_vol(r, c)}
        end
        # Assocaite todays_date with item
        Item.find(cal_plate.id).associate('date_created', todays_date)
        release cal_items, interactive: true
        return cal_plate
    end
    
    def ludox_vol(row, col)
        if col < 4
            return "100µl"
        elsif col.between?(4, 7)
            return "200µl"
        else col.between?(7, 11)
            return "300µl"
        end
    end
    
    # This function directs tech to measure calibration plate on plate reader and export data; it also associates data from plate reader
    #
    # @params cal_plates [Array] an array of item objects
    #
    def measure_cal_plate(cal_plate)
        # measure on plate reader 
        set_up_plate_reader(cal_plate, CAL_TEMPLATE_FILENAME)
        
        # Export a file for each measurement
        CAL_MEASUREMENTS.each do |method|
            
            timepoint = nil # Is nil since it is not being measured along with this experiment
            filename = export_data(cal_plate, timepoint, method=method)
            
            # Show block upload button and retrieval of file uploaded
            up_show, up_sym = upload_show(filename)
            if (up_show[up_sym].nil?)
                show {warning "No upload found for calibration measurement. Try again!!!"}
                up_show, up_sym = upload_show(filename)
            else
                upload = find_upload_from_show(up_show, up_sym)
                key = "#{todays_date}_#{method}"
                
                # Associates upload to calibration plate and plan
                associate_to_plans(key, upload)
                associate_to_item(cal_plate, key, upload)
                # Associates data hash of measurements to item/collection - extract info from plate reader upload and associate with item
                associate_PlateReader_Data(upload, cal_plate, method, timepoint)
            end
        end
        cal_plate.location = '4°C Fridge'
        # cal_plate.mark_as_deleted
    end
#-------------------------------------------------PlateReaderControl-----------------------------------------------------#
  
  
  
  
  
end #module