function change_matlab_title(new_title)
    desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
    desktop.getMainFrame.setTitle(new_title);
end